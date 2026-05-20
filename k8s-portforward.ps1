param([switch]$Stop)

$forwards = @(
    @{ Name = "users-api";              Svc = "users-api-service";              Local = 5001; Remote = 80   }
    @{ Name = "catalog-api";            Svc = "catalog-api-service";            Local = 5004; Remote = 80   }
    @{ Name = "payments-api";           Svc = "payments-api-service";           Local = 5003; Remote = 80   }
    @{ Name = "notifications-func";     Svc = "notifications-functions-service"; Local = 5002; Remote = 80  }
    @{ Name = "rabbitmq-management";    Svc = "rabbitmq-service";               Local = 15672; Remote = 15672 }
    @{ Name = "prometheus";             Svc = "prometheus-service";             Local = 9090; Remote = 9090 }
    @{ Name = "grafana";                Svc = "grafana-service";                Local = 3000; Remote = 3000 }
    @{ Name = "kong-proxy";             Svc = "kong-service";                   Local = 8000; Remote = 8000 }
)

if ($Stop) {
    Write-Host "Encerrando port-forwards..." -ForegroundColor Yellow
    Get-Job -Name "pf-*" | Stop-Job | Remove-Job
    Write-Host "Encerrado." -ForegroundColor Green
    exit 0
}

# Para jobs antigos antes de reabrir
Get-Job -Name "pf-*" -ErrorAction SilentlyContinue | Stop-Job | Remove-Job

Write-Host "Iniciando port-forwards..." -ForegroundColor Cyan

foreach ($f in $forwards) {
    Start-Job -Name "pf-$($f.Name)" -ScriptBlock {
        param($svc, $local, $remote)
        kubectl port-forward "svc/$svc" "${local}:${remote}" --address 127.0.0.1
    } -ArgumentList $f.Svc, $f.Local, $f.Remote | Out-Null

    Write-Host "  $($f.Name.PadRight(22)) http://localhost:$($f.Local)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Credenciais:" -ForegroundColor Yellow
Write-Host "  RabbitMQ  guest / guest"
Write-Host "  Grafana   admin / admin"
Write-Host ""
Write-Host "Para encerrar: .\k8s-portforward.ps1 -Stop" -ForegroundColor Gray
Write-Host "Jobs ativos:   Get-Job -Name 'pf-*'" -ForegroundColor Gray
