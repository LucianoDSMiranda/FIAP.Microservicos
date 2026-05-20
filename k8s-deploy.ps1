param(
    [switch]$BuildImages,
    [switch]$Down
)

$ErrorActionPreference = "Stop"

function Invoke-Kubectl {
    param([string[]]$Arguments)
    kubectl @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "kubectl $($Arguments -join ' ') falhou com codigo $LASTEXITCODE"
    }
}

function Wait-Pods {
    param([string]$Label, [int]$TimeoutSeconds = 120)
    Write-Host "  Aguardando pods '$Label'..." -ForegroundColor Yellow
    kubectl wait pod --for=condition=Ready -l $Label --timeout="${TimeoutSeconds}s"
    if ($LASTEXITCODE -ne 0) {
        throw "Timeout aguardando pods com label '$Label'"
    }
    Write-Host "  OK" -ForegroundColor Green
}

# Verifica contexto do kubectl
Write-Host "Verificando contexto kubectl..." -ForegroundColor Gray
$currentContext = kubectl config current-context 2>$null
if ($LASTEXITCODE -ne 0 -or $currentContext -notmatch "docker-desktop") {
    if ($currentContext) {
        Write-Host "  Contexto atual: $currentContext" -ForegroundColor Yellow
    }
    Write-Host "  Trocando para docker-desktop..." -ForegroundColor Yellow
    kubectl config use-context docker-desktop
    if ($LASTEXITCODE -ne 0) {
        throw "Nao foi possivel usar o contexto docker-desktop. Verifique se o Kubernetes esta habilitado no Docker Desktop (Settings > Kubernetes > Enable Kubernetes)."
    }
}
Write-Host "  Contexto: $(kubectl config current-context 2>$null)" -ForegroundColor Green

if ($Down) {
    Write-Host "Removendo todos os recursos do cluster..." -ForegroundColor Red
    kubectl delete -f Notification/k8s/      --ignore-not-found
    kubectl delete -f FIAP.Payments/k8s/     --ignore-not-found
    kubectl delete -f FIAP.Catalog/k8s/      --ignore-not-found
    kubectl delete -f User/k8s/              --ignore-not-found
    kubectl delete -f k8s/monitoring/        --ignore-not-found
    kubectl delete -f k8s/kong/              --ignore-not-found
    kubectl delete -f k8s/                   --ignore-not-found
    Write-Host "Cluster limpo." -ForegroundColor Green
    exit 0
}

if ($BuildImages) {
    Write-Host "`n[BUILD] Buildando imagens locais (Docker Desktop)..." -ForegroundColor Cyan

    Write-Host "  Build users-api..."
    docker build -t fiapmicroservicos-users-api ./User -q
    if ($LASTEXITCODE -ne 0) { throw "Build users-api falhou" }

    Write-Host "  Build catalog-api..."
    docker build -t fiapmicroservicos-catalog-api ./FIAP.Catalog -q
    if ($LASTEXITCODE -ne 0) { throw "Build catalog-api falhou" }

    Write-Host "  Build payments-api..."
    docker build -t fiapmicroservicos-payments-api ./FIAP.Payments -q
    if ($LASTEXITCODE -ne 0) { throw "Build payments-api falhou" }

    Write-Host "  Build notifications-functions..."
    docker build -t fiapmicroservicos-notifications-functions ./Notification -q
    if ($LASTEXITCODE -ne 0) { throw "Build notifications-functions falhou" }

    Write-Host "  Imagens prontas." -ForegroundColor Green
}

# 1. Infraestrutura compartilhada
Write-Host "`n[1/5] Infra: MongoDB, RabbitMQ, Redis..." -ForegroundColor Cyan
Invoke-Kubectl "apply", "-f", "k8s/mongo-pvc.yaml"
Invoke-Kubectl "apply", "-f", "k8s/mongo-deployment.yaml"
Invoke-Kubectl "apply", "-f", "k8s/mongo-service.yaml"
Invoke-Kubectl "apply", "-f", "k8s/rabbitmq-secret.yaml"
Invoke-Kubectl "apply", "-f", "k8s/rabbitmq-deployment.yaml"
Invoke-Kubectl "apply", "-f", "k8s/rabbitmq-service.yaml"
Invoke-Kubectl "apply", "-f", "k8s/redis-deployment.yaml"
Invoke-Kubectl "apply", "-f", "k8s/redis-service.yaml"

Wait-Pods "app=mongo"
Wait-Pods "app=rabbitmq"
Wait-Pods "app=redis"

# 2. Azurite (necessario para Notifications)
Write-Host "`n[2/5] Azurite (Azure Storage emulator)..." -ForegroundColor Cyan
Invoke-Kubectl "apply", "-f", "Notification/k8s/azurite.yaml"
Wait-Pods "app=azurite"

# 3. Monitoring
Write-Host "`n[3/5] Monitoring: Prometheus + Grafana..." -ForegroundColor Cyan
Invoke-Kubectl "apply", "-f", "k8s/monitoring/"
Wait-Pods "app=prometheus"
Wait-Pods "app=grafana"

# 4. Microsservicos
Write-Host "`n[4/5] Microsservicos..." -ForegroundColor Cyan
Invoke-Kubectl "apply", "-f", "User/k8s/"
Invoke-Kubectl "apply", "-f", "FIAP.Catalog/k8s/"
Invoke-Kubectl "apply", "-f", "FIAP.Payments/k8s/"
Invoke-Kubectl "apply", "-f", "Notification/k8s/"

Wait-Pods "app=users-api"
Wait-Pods "app=catalog-api"
Wait-Pods "app=payments-api"
Wait-Pods "app=notifications-functions"

# 5. Kong API Gateway
# --validate=false necessario porque o kubectl tenta baixar o schema OpenAPI
# do servidor via HTTP sem contexto durante a validacao de ConfigMap com dados YAML aninhados
Write-Host "`n[5/5] Kong API Gateway..." -ForegroundColor Cyan
Invoke-Kubectl "apply", "--validate=false", "-f", "k8s/kong/kong.yaml"
Wait-Pods "app=kong"

# Resumo das URLs
Write-Host "`n========================================" -ForegroundColor Green
Write-Host " Cluster pronto!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host ""
Write-Host "URLs de acesso (NodePort):"

$services = @{
    "Users API"           = "users-api-service"
    "Catalog API"         = "catalog-api-service"
    "Payments API"        = "payments-api-service"
    "Notifications Func"  = "notifications-functions-service"
    "RabbitMQ Management" = "rabbitmq-service"
    "Prometheus"          = "prometheus-service"
    "Grafana"             = "grafana-service"
}

foreach ($name in $services.Keys) {
    $svc = $services[$name]
    $port = kubectl get svc $svc -o jsonpath='{.spec.ports[0].nodePort}' 2>$null
    if ($port) {
        Write-Host "  $name`t http://localhost:$port"
    }
}
Write-Host ""

# Reinicia port-forwards automaticamente após o deploy
$pfScript = Join-Path $PSScriptRoot "k8s-portforward.ps1"
if (Test-Path $pfScript) {
    Write-Host "Reiniciando port-forwards..." -ForegroundColor Cyan
    & $pfScript
}
