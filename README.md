
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

---

## Docker Compose (desenvolvimento local)

Sobe todos os serviços com um único comando a partir da raiz:

```bash
docker compose up --build
```

### Serviços e portas (Docker Compose)

| Serviço | URL |
|---|---|
| Users API | http://localhost:5001 |
| Notifications Functions | http://localhost:5002 |
| Payments API | http://localhost:5003 |
| Catalog API | http://localhost:5004 |
| RabbitMQ Management | http://localhost:15672 (guest / guest) |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3000 (admin / admin) |

---

## Kubernetes (Docker Desktop)

### Deploy completo — script automático

O script cuida da ordem correta de criação, aguarda cada grupo de pods ficar `Ready` antes de avançar e abre os port-forwards automaticamente ao final.

**Windows (PowerShell):**

```powershell
# Primeira execução: faz o build das imagens + deploy
.\k8s-deploy.ps1 -BuildImages

# Execuções seguintes (sem rebuild)
.\k8s-deploy.ps1

# Derrubar tudo
.\k8s-deploy.ps1 -Down
```

**Linux / Mac:**

```bash
chmod +x k8s-deploy.sh

# Primeira execução
./k8s-deploy.sh --build

# Execuções seguintes
./k8s-deploy.sh

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

---

## Acessando os serviços no Kubernetes

Como o Docker Desktop no Windows não encaminha NodePorts de forma confiável, usa-se `kubectl port-forward`. O script abre todas as conexões em background:

```powershell
.\k8s-portforward.ps1          # Abre todos os port-forwards
.\k8s-portforward.ps1 -Stop    # Encerra todos
```

> Os port-forwards ficam ativos enquanto a sessão do PowerShell estiver aberta. Após um `kubectl rollout restart`, rode o script novamente para reestabelecer as conexões.

### URLs de acesso (Kubernetes via port-forward)

| Serviço | URL | Credenciais |
|---|---|---|
| **Kong API Gateway** | http://localhost:8000 | — |
| Swagger Users | http://localhost:8000/users/ | — |
| Swagger Catalog | http://localhost:8000/catalog/ | — |
| RabbitMQ Management | http://localhost:15672 | guest / guest |
| Prometheus | http://localhost:9090 | — |
| Grafana | http://localhost:3000 | admin / admin |

---

## Kong API Gateway

O Kong é o ponto único de entrada para as APIs. Todas as requisições passam por ele e são validadas com JWT.

### Roteamento

| Path Kong | Serviço destino | Autenticação |
|---|---|---|
| `/users/*` | users-api-service:80 | JWT (anônimo permitido) |
| `/catalog/*` | catalog-api-service:80 | JWT (anônimo permitido) |

### Autenticação JWT

Para acessar endpoints protegidos via Swagger ou direto:

1. Faça login em `POST /users/api/Auth/login`
2. Copie o token retornado
3. No Swagger, clique em **Authorize** e informe: `Bearer {token}`

### Consumer configurado

```
username: cloudgames-user
key: cloudgames-key
secret: SUPER_SECRET_KEY_123456789_123456789
```

---

## MongoDB

### Acesso via shell

```bash
kubectl port-forward service/mongo-service 27017:27017
docker run --rm -it --network host mongo:7 mongosh mongodb://localhost:27017
```

### Consultando dados

```javascript
// Usuários
use cloudgames_users
db.users.find().pretty()

// Catálogo
use cloudgames_catalog
db.games.find().pretty()
db.userGames.find().pretty()
```

---

## Logs centralizados (Redis Stream)

Todos os microsserviços (exceto Notifications Functions) publicam logs estruturados via Serilog no Redis Stream `cloudgames:logs`.

### Inspecionando logs via CLI

```bash
# Últimas 10 entradas
docker run --rm --network host redis:7-alpine redis-cli -h localhost XREVRANGE cloudgames:logs + - COUNT 10

# Total de entradas
docker run --rm --network host redis:7-alpine redis-cli -h localhost XLEN cloudgames:logs
```

### Visualizando no Grafana

Acesse http://localhost:3000 → Dashboards → **CloudGames - Overview**

Datasources já provisionados: `Prometheus` (métricas) e `Redis` (logs).

---

## Métricas (Prometheus + Grafana)

Cada microsserviço (exceto Notifications Functions) expõe métricas no endpoint `/metrics`.

| Métrica | Significado |
|---|---|
| `http_requests_received_total` | Contador de requisições por código HTTP / método |
| `http_request_duration_seconds` | Histograma de latência |
| `http_requests_in_progress` | Requisições em andamento |
| `dotnet_total_memory_bytes` | Tamanho do heap gerenciado |
| `process_cpu_seconds_total` | CPU acumulado pelo processo |

> ℹ️ O serviço `notifications-functions` **não expõe `/metrics`** pois é uma Azure Function — não utiliza `prometheus-net`.

Verifique os targets ativos: http://localhost:9090 → Status → Targets

---

## Logs dos pods

```bash
kubectl logs deployment/users-api
kubectl logs deployment/catalog-api
kubectl logs deployment/payments-api
kubectl logs deployment/notifications-functions
```

---

## Observações sobre a arquitetura

- **Notifications** roda como **Azure Functions v4** (dotnet-isolated) e requer o **Azurite** como emulador do Azure Storage. Sem ele o runtime das Functions não inicializa.
- O serviço de Notifications **não é uma Web API** — não possui Swagger, endpoints HTTP próprios nem métricas Prometheus. Ele consome eventos do RabbitMQ (`UserCreated`, `PaymentProcessed`) e envia e-mails simulados via `Console.WriteLine`.
- O **Kong** usa `strip_path: true` — o prefixo `/users` ou `/catalog` é removido antes de encaminhar para o microsserviço. O Swagger de cada API usa caminho relativo e server URL dinâmica baseada no host da requisição.
