#!/usr/bin/env bash
# Ações do executor. Variáveis esperadas:
#   ACTION         validate | plan | apply | destroy | image | migrate | test
#   RUNNER_BUCKET  bucket com o código (src/), o state e os planos
#   LAB_ENV        nome do ambiente (padrão: dev)
#   TFVARS_JSON    variáveis do Terraform em JSON (sem segredos)
#   PLAN_ID        identificador do plano a gerar ou aplicar
#   IMAGE_TAG      tag da imagem a construir
set -euo pipefail

LAB_ENV="${LAB_ENV:-dev}"
REGION="${AWS_REGION:-us-east-1}"
TF_DIR="infra/aws/terraform"
PLAN_ID="${PLAN_ID:-latest}"
PLAN_KEY="plans/${LAB_ENV}/${PLAN_ID}.tfplan"

tf_init() {
  terraform -chdir="$TF_DIR" init -no-color \
    -backend-config="bucket=${RUNNER_BUCKET}" \
    -backend-config="key=state/${LAB_ENV}/terraform.tfstate" \
    -backend-config="region=${REGION}"
}

tf_vars() {
  if [ -n "${TFVARS_JSON:-}" ]; then
    printf '%s' "$TFVARS_JSON" > "$TF_DIR/runner.auto.tfvars.json"
  fi
}

tf_output() { terraform -chdir="$TF_DIR" output -raw "$1"; }

case "$ACTION" in
  validate)
    echo "== terraform fmt (diferenças, se houver) =="
    terraform -chdir="$TF_DIR" fmt -recursive -diff -check -no-color || echo "FMT: há arquivos fora do padrão"
    terraform -chdir="$TF_DIR" init -no-color -backend=false
    terraform -chdir="$TF_DIR" validate -no-color
    echo "== versões dos provedores selecionadas =="
    cat "$TF_DIR/.terraform.lock.hcl"
    ;;

  plan)
    tf_vars
    tf_init
    terraform -chdir="$TF_DIR" plan -no-color -out=/tmp/lab.tfplan
    aws s3 cp /tmp/lab.tfplan "s3://${RUNNER_BUCKET}/${PLAN_KEY}" --only-show-errors
    echo "PLANO SALVO: ${PLAN_KEY}"
    ;;

  plan-destroy)
    tf_vars
    tf_init
    terraform -chdir="$TF_DIR" plan -destroy -no-color -out=/tmp/lab.tfplan
    aws s3 cp /tmp/lab.tfplan "s3://${RUNNER_BUCKET}/${PLAN_KEY}" --only-show-errors
    echo "PLANO DE DESTRUIÇÃO SALVO: ${PLAN_KEY}"
    ;;

  apply)
    # Aplica exatamente o plano que foi revisado, sem recalcular.
    tf_init
    aws s3 cp "s3://${RUNNER_BUCKET}/${PLAN_KEY}" /tmp/lab.tfplan --only-show-errors
    terraform -chdir="$TF_DIR" apply -no-color /tmp/lab.tfplan
    terraform -chdir="$TF_DIR" output -no-color
    ;;

  image)
    tf_init
    repository="$(tf_output ecr_repository_url)"
    registry="${repository%%/*}"
    tag="${IMAGE_TAG:?informe IMAGE_TAG}"
    aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$registry"
    # O espelho do registro público evita o limite de requisições do Docker Hub.
    docker build \
      --build-arg BASE_IMAGE=public.ecr.aws/docker/library/python:3.12-slim \
      --tag "${repository}:${tag}" app
    test "$(docker run --rm --entrypoint id "${repository}:${tag}" -u)" != "0"
    docker push "${repository}:${tag}"
    echo "IMAGEM: ${repository}:${tag}"
    docker inspect --format 'DIGEST: {{index .RepoDigests 0}}' "${repository}:${tag}"
    docker inspect --format 'BASE: {{index .Config.Labels "org.opencontainers.image.base.name"}}' "${repository}:${tag}" || true
    ;;

  migrate)
    tf_init
    cluster="$(tf_output ecs_cluster_name)"
    task_definition="$(tf_output migrate_task_definition_arn)"
    subnets="$(terraform -chdir="$TF_DIR" output -json task_subnet_ids | tr -d '[]" ')"
    security_group="$(tf_output task_security_group_id)"
    public_ip="DISABLED"
    [ "$(tf_output task_assign_public_ip)" = "true" ] && public_ip="ENABLED"
    task_arn="$(aws ecs run-task --cluster "$cluster" --task-definition "$task_definition" \
      --launch-type FARGATE --count 1 \
      --network-configuration "awsvpcConfiguration={subnets=[${subnets}],securityGroups=[${security_group}],assignPublicIp=${public_ip}}" \
      --query 'tasks[0].taskArn' --output text)"
    echo "TASK DE MIGRAÇÃO: ${task_arn##*/}"
    aws ecs wait tasks-stopped --cluster "$cluster" --tasks "$task_arn"
    exit_code="$(aws ecs describe-tasks --cluster "$cluster" --tasks "$task_arn" \
      --query 'tasks[0].containers[0].exitCode' --output text)"
    aws logs tail "$(tf_output app_log_group_name)" --since 15m --log-stream-name-prefix "ecs/migrate" --format short || true
    echo "CÓDIGO DE SAÍDA DA MIGRAÇÃO: ${exit_code}"
    test "$exit_code" = "0"
    ;;

  test)
    tf_init
    url="$(tf_output service_url)"
    export INSECURE="${INSECURE:-1}"
    echo "== smoke test =="
    bash scripts/smoke-test.sh "$url"
    echo "== distribuição entre tasks =="
    bash scripts/test-ha.sh "$url" "${TEST_REQUESTS:-12}" 2
    if [ "${FAILOVER_SECONDS:-0}" != "0" ]; then
      echo "== janela de failover =="
      bash scripts/test-failover.sh "$url" "$FAILOVER_SECONDS" "${FAILOVER_INTERVAL:-0.5}"
    fi
    ;;

  destroy)
    tf_init
    aws s3 cp "s3://${RUNNER_BUCKET}/${PLAN_KEY}" /tmp/lab.tfplan --only-show-errors
    terraform -chdir="$TF_DIR" apply -no-color /tmp/lab.tfplan
    ;;

  *)
    echo "ACTION desconhecida: ${ACTION}" >&2
    exit 2
    ;;
esac
