# ADR-002 — ECS em Fargate em vez de EC2 na fase inicial

- **Status:** Aceito
- **Data:** 03/10/2026

## Contexto

A aplicação é um único container sem estado, com duas réplicas. Na origem, cada réplica roda em uma VM mantida à mão: sistema operacional, Docker, Nginx e build local da imagem.

## Decisão

Executar a aplicação no **Amazon ECS com Fargate**: um serviço com no mínimo duas tasks, distribuídas em duas zonas de disponibilidade, com deploy rolling e reversão automática em caso de falha.

## Alternativas consideradas

| Alternativa | A favor | Por que não |
| --- | --- | --- |
| ECS em EC2 com Auto Scaling | Custo por hora menor em carga constante; acesso ao host | Devolve patching, AMI e dimensionamento do cluster. Para duas tasks pequenas, a economia é de poucos dólares por mês |
| EC2 com Docker Compose | É o que já existe | É rehost: não reduz operação nem demonstra a decisão de replatforming |
| Kubernetes gerenciado | Portabilidade e ecossistema | Plano de controle com custo fixo e complexidade desproporcional a um serviço |

## Consequências

- Não há sistema operacional, AMI nem capacidade de cluster para gerir.
- O custo por vCPU é maior que o de EC2; em carga alta e constante, a decisão deve ser revista.
- Não há acesso ao host: diagnóstico é feito por logs, métricas e, se necessário, sessão no container.
- A imagem precisa estar em um registro; o build local por instância deixa de existir.
