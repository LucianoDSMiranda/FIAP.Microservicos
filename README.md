
# FIAP.Microservicos

Repositório responsável pela orquestração dos microserviços do projeto **CloudGames**, centralizando a execução dos serviços por meio do **Docker Compose** e do **Kubernetes**.

## Estrutura do projeto

Este repositório utiliza **submodules** para referenciar os microserviços, que estão separados em repositórios independentes.

## Repositórios utilizados

| Submodule | Repositório | Tipo |
|---|---|---|
| `User/` | cloudgames-users-api | ASP.NET Core Web API |
| `FIAP.Catalog/` | FIAP.Catalog | ASP.NET Core Web API |
| `FIAP.Payments/` | FIAP.Payments | Worker Service (MassTransit Consumer) |
| `Notification/` | cloudgames-notifications-api | **Azure Functions v4** (dotnet-isolated) |

> ⚠️ O serviço `Notification` foi migrado de Web API para **Azure Functions serverless**. Ele não expõe endpoints HTTP nem métricas Prometheus — consome eventos do RabbitMQ via trigger.

## Estrutura de diretórios

```text
FIAP.Microservicos/
├── docker-compose.yml          # Orquestração completa (todos os serviços + infra)
├── k8s-deploy.ps1              # Script de deploy Kubernetes (Windows)
├── k8s-deploy.sh               # Script de deploy Kubernetes (Linux/Mac)
├── k8s-portforward.ps1         # Script de port-forward para acesso local
├── README.md
├── FIAP.Payments/
├── FIAP.Catalog/
├── Notification/
├── User/
├── k8s/                        # Manifests de infra compartilhada
│   ├── mongo-*.yaml
│   ├── rabbitmq-*.yaml
│   ├── redis-*.yaml
│   ├── monitoring/
│   │   ├── prometheus-config.yaml
│   │   ├── prometheus-deployment.yaml
│   │   └── grafana-deployment.yaml
│   └── kong/
│       └── kong.yaml
└── monitoring/
    ├── prometheus.yml
    └── grafana/
        └── provisioning/
```

## Infraestrutura e observabilidade

| Recurso | Tecnologia | Função |
|---|---|---|
| **MongoDB** | `mongo:7` | Banco principal dos serviços `User` (DB `cloudgames_users`) e `Catalog` (DB `cloudgames_catalog`) |
| **Redis** | `redis:7-alpine` | Sink central de logs estruturados via Redis Stream `cloudgames:logs` |
| **RabbitMQ** | `rabbitmq:3-management` | Mensageria entre os microsserviços (MassTransit) |
| **Azurite** | `mcr.microsoft.com/azure-storage/azurite` | Emulador do Azure Storage — obrigatório para o runtime das Azure Functions |
| **Prometheus** | `prom/prometheus:latest` | Coleta métricas de `users-api`, `catalog-api` e `payments-api` a cada 15s |
| **Grafana** | `grafana/grafana:latest` | Dashboards de métricas (Prometheus) e logs (Redis Stream) |
| **Kong** | `kong:3.6` | API Gateway — ponto único de entrada com autenticação JWT |

## Pré-requisitos

- Docker Desktop com **Kubernetes habilitado** (Settings → Kubernetes → Enable Kubernetes)
- `kubectl` configurado e apontando para o contexto `docker-desktop`

## Clonando o projeto

```bash
git clone --recurse-submodules https://github.com/LucianoDSMiranda/FIAP.Microservicos.git
```

Se já clonou sem submodules:

```bash
git submodule update --init --recursive
```

## Kubernetes (Docker Desktop)

### Deploy completo — script automático

O script cuida da ordem correta de criação, aguarda cada grupo de pods ficar `Ready` antes de avançar e abre os port-forwards automaticamente ao final.

**Windows (PowerShell):**

```powershell
# Primeira execução: faz o build das imagens + deploy
.\k8s-deploy.ps1 -BuildImages

# Derrubar tudo
.\k8s-deploy.ps1 -Down
```

**Linux / Mac:**

```bash
chmod +x k8s-deploy.sh

# Primeira execução
./k8s-deploy.sh --build

# Derrubar tudo
./k8s-deploy.sh --down
```

### Ordem de deploy (referência)

O script aplica na seguinte sequência:

1. Infra compartilhada: MongoDB → RabbitMQ → Redis
2. Azurite (Azure Storage emulator — necessário para Notifications Functions)
3. Monitoring: Prometheus → Grafana
4. Microsserviços: Users → Catalog → Payments → Notifications
5. Kong API Gateway

### Imagens Docker esperadas

| Imagem | Contexto de build |
|---|---|
| `fiapmicroservicos-users-api` | `./User` |
| `fiapmicroservicos-catalog-api` | `./FIAP.Catalog` |
| `fiapmicroservicos-payments-api` | `./FIAP.Payments` |
| `fiapmicroservicos-notifications-functions` | `./Notification` |

Para forçar rebuild sem cache de uma imagem específica:

```powershell
docker build --no-cache -t fiapmicroservicos-catalog-api ./FIAP.Catalog
kubectl rollout restart deployment/catalog-api
```

### URLs de acesso (Kubernetes via port-forward)
#### Kong API Gateway

O Kong é o ponto único de entrada para as APIs. Todas as requisições passam por ele e são validadas com JWT.

| Serviço | URL | Credenciais |
|---|---|---|
| Swagger Users | http://localhost:8000/users/ | — |
| Swagger Catalog | http://localhost:8000/catalog/ | — |
| RabbitMQ Management | http://localhost:15672 | guest / guest |
| Prometheus | http://localhost:9090 | — |
| Grafana | http://localhost:3000 | admin / admin |

---


### Autenticação JWT

Para acessar endpoints protegidos via Swagger ou direto:

1. Faça login em `POST /users/api/Auth/login`
user

  "email": "admin@cloudgames.com",
  "password": "Admin123!"


2. Copie o token retornado
3. No Swagger, clique em **Authorize** e informe: `Bearer {token}`


## Logs centralizados (Redis Stream)

Todos os microsserviços publicam logs estruturados via Serilog no Redis Stream `cloudgames:logs`.


### Visualizando no Grafana

Acesse http://localhost:3000 → Dashboards → **CloudGames - Overview**

Datasources já provisionados: `Prometheus` (métricas) e `Redis` (logs).

---

## Métricas (Prometheus + Grafana)

Cada microsserviço (exceto Notifications Functions) expõe métricas no endpoint `/metrics`.

---

## Observações sobre a arquitetura

- **Notifications** roda como **Azure Functions v4** (dotnet-isolated) e requer o **Azurite** como emulador do Azure Storage. Sem ele o runtime das Functions não inicializa.
- O serviço de Notifications **não é uma Web API** — não possui Swagger, endpoints HTTP próprios nem métricas Prometheus. Ele consome eventos do RabbitMQ (`UserCreated`, `PaymentProcessed`) e envia e-mails simulados via log.
- O **Kong** usa `strip_path: true` — o prefixo `/users` ou `/catalog` é removido antes de encaminhar para o microsserviço. O Swagger de cada API usa caminho relativo e server URL dinâmica baseada no host da requisição.
