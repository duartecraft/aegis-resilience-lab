<#
.SYNOPSIS
  Verifica a distribuição de requisições entre os nós da aplicação.

.EXAMPLE
  ./scripts/test-ha.ps1 -BaseUrl https://api.aegis.example.com
  ./scripts/test-ha.ps1 -BaseUrl https://<endereco-do-load-balancer> -Requests 20 -Insecure
#>
param(
  [Parameter(Mandatory = $true)][string]$BaseUrl,
  [int]$Requests = 12,
  [int]$MinNodes = 2,
  [switch]$Insecure
)

$ErrorActionPreference = 'Stop'
$BaseUrl = $BaseUrl.TrimEnd('/')
$curlArgs = @('--silent', '--max-time', '10')
if ($Insecure) { $curlArgs += '--insecure' }

Write-Output "Alvo: $BaseUrl/api/status | requisicoes: $Requests | minimo de nos: $MinNodes"
Write-Output ("Inicio (UTC): " + (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))

$nodes = @()
$errors = 0
for ($i = 1; $i -le $Requests; $i++) {
  try {
    # curl.exe acompanha o Windows 10 e 11 e evita diferenças entre versões do PowerShell.
    $body = & curl.exe @curlArgs "$BaseUrl/api/status" | ConvertFrom-Json
    $nodes += $body.node
    Write-Output ('{0,3}  {1} {2} {3}' -f $i, $body.node, $body.version, $body.database.connected)
  } catch {
    $errors++
    Write-Output ('{0,3}  ERRO' -f $i)
  }
}

Write-Output ''
Write-Output 'Respostas por no:'
$nodes | Group-Object | ForEach-Object { Write-Output ('  {0,4} {1}' -f $_.Count, $_.Name) }
$distinct = ($nodes | Sort-Object -Unique | Measure-Object).Count
Write-Output "Nos distintos: $distinct | erros: $errors"

if ($distinct -lt $MinNodes -or $errors -gt 0) {
  Write-Output 'RESULTADO: FALHA'
  exit 1
}
Write-Output 'RESULTADO: OK'
