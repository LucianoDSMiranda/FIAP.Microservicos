
# FIAP.Microservicos

Repositório responsável pela orquestração dos microserviços do projeto **CloudGames**, centralizando a execução dos serviços por meio do **Docker Compose** e do **Kubernetes**.

## Estrutura do projeto

Este repositório utiliza **submodules** para referenciar os microserviços, que estão separados em repositórios independentes.

## Repositórios utilizados

- **FIAP.Payments**
- **FIAP.Catalog**
- **cloudgames-notifications-api**
- **cloudgames-users-api**

## Estrutura esperada

```text
FIAP.Microservicos/
├── docker-compose.yml
├── README.md
├── FIAP.Payments/
├── FIAP.Catalog/
├── Notification/
├── User/
└── k8s/
```

## Persistência e observabilidade

| Recurso | Tecnologia | Função |
|---|---|---|
| **MongoDB** | `mongo:7` | Banco principal dos serviços `User` (DB `cloudgames_users`) e `Catalog` (DB `cloudgames_catalog`). |
| **Redis** | `redis:7-alpine` | Sink central de logs estruturados via Redis Stream `cloudgames:logs`. Todos os 4 microsserviços publicam logs via Serilog. |
| **RabbitMQ** | `rabbitmq:3-management` | Mensageria entre os microsserviços (MassTransit). |
| **Prometheus** | `prom/prometheus:latest` | Coleta métricas HTTP/runtime dos 4 microsserviços via endpoint `/metrics` (prometheus-net). |
| **Grafana** | `grafana/grafana:latest` | Dashboards de métricas (Prometheus) e logs (Redis Streams via plugin `redis-datasource`). |

## Clonando o projeto

Como este repositório utiliza submodules, recomenda-se realizar o clone com o comando abaixo:

```bash
git clone --recurse-submodules https://github.com/LucianoDSMiranda/FIAP.Microservicos.git
```

## Pré-requisitos

Para executar o projeto, é necessário ter instalado e configurado:

* Docker Desktop
* Kubernetes habilitado no Docker Desktop
* `kubectl` configurado na máquina

## Build do ambiente

Após clonar o projeto, acesse a raiz do repositório e execute:

```bash
docker compose build --no-cache
docker pull rabbitmq:3-management
docker pull mongo:7
docker pull redis:7-alpine
```

## Subindo o ambiente no Kubernetes

Com o Kubernetes iniciado pela interface do Docker Desktop, aplique os arquivos da pasta `k8s` de cada projeto.

Entre na raiz de cada microserviço e execute:

```bash
\User> kubectl apply -f k8s/
\Notification> kubectl apply -f k8s/
\FIAP.Catalog> kubectl apply -f k8s/
\FIAP.Payments> kubectl apply -f k8s/
```

Esse processo também deve ser feito no projeto raiz **FIAP.Microservicos**, responsável por iniciar serviços compartilhados (RabbitMQ, MongoDB, Redis):

```bash
\FIAP.Microservicos> kubectl apply -f k8s/
```

## Acesso às APIs

Atualmente, o projeto utiliza o Kong API Gateway como ponto único de entrada para as requisições externas.

O Kong é responsável por:

- Receber todas as requisições externas
- Validar o token JWT
- Realizar o roteamento para os microserviços internos
- Centralizar o acesso às APIs


## Subindo o Kong Gateway

Após subir os microserviços no Kubernetes, aplique a configuração do Kong:

```bash
\k8s\kong> kubectl apply -f kong.yaml
```

## Expondo o Kong Gateway

Primeiramente, verifique os services disponíveis:

```bash
\k8s\kong> kubectl get svc
```

Após localizar o service do Kong, execute:

```bash
\k8s\kong> kubectl port-forward service/kong-service 8010:8000
```

## Endpoints disponíveis

### Users API

```text
http://localhost:8010/users/index.html
```

### Catalog API

```text
http://localhost:8010/catalog/index.html
```

Todas as requisições realizadas nesses endpoints passam obrigatoriamente pelo Kong Gateway.

---

## RabbitMQ Management

Para acessar o painel administrativo do RabbitMQ:

```bash
kubectl port-forward service/rabbitmq-service 15672:15672
```

Acesso:

```text
http://localhost:15672
```

Usuário/Senha:

```text
guest / guest
```

## MongoDB

### Acesso via shell

```bash
kubectl port-forward service/mongo-service 27017:27017
docker run --rm -it --network host mongo:7 mongosh mongodb://localhost:27017
```

### Verificando dados

```javascript
// Usuários
use cloudgames_users
db.users.find().pretty()

// Jogos / catálogo
use cloudgames_catalog
db.games.find().pretty()
db.userGames.find().pretty()
```

## Logs centralizados (Redis Stream)

Todos os microsserviços publicam logs estruturados no Redis Stream `cloudgames:logs`. Cada entrada contém os campos `timestamp`, `level`, `service`, `message`, `template`, `properties` e `exception`.

### Inspecionando logs

```bash
kubectl port-forward service/redis-service 6379:6379

# Total de entradas no stream
docker run --rm --network host redis:7-alpine redis-cli -h localhost XLEN cloudgames:logs

# Últimas 10 entradas (mais recentes primeiro)
docker run --rm --network host redis:7-alpine redis-cli -h localhost XREVRANGE cloudgames:logs + - COUNT 10
```

> **Dica:** O `RedisInsight` (https://redis.com/redis-enterprise/redis-insight/) oferece interface gráfica para explorar streams.

## Métricas e dashboards (Prometheus + Grafana)

Cada microsserviço expõe métricas no endpoint `/metrics` (HTTP request rate, latência, status codes, GC, CPU, memória .NET). O Prometheus faz scrape a cada 15s e o Grafana mostra os dashboards.

### Subindo no Docker Compose

```bash
docker compose up -d prometheus grafana
```

### Acessando

- **Prometheus UI:** http://localhost:9090 (verifique `Status → Targets` — todos devem ficar `UP`)
- **Grafana UI:** http://localhost:3000 — login `admin` / `admin`
  - Dashboard pré-provisionado: `Dashboards → CloudGames → CloudGames - Overview`
  - Datasources já configurados: `Prometheus` (métricas) e `Redis` (logs do stream)

### Métricas relevantes expostas

| Métrica | Significado |
|---|---|
| `http_requests_received_total` | Contador de requisições por código HTTP / método |
| `http_request_duration_seconds` | Histograma de latência (use `histogram_quantile` para p95/p99) |
| `http_requests_in_progress` | Requisições em andamento agora |
| `dotnet_total_memory_bytes` | Tamanho do heap gerenciado |
| `process_cpu_seconds_total` | CPU acumulado pelo processo |

### Subindo no Kubernetes

```bash
\FIAP.Microservicos> kubectl apply -f k8s/monitoring/
```

E expor:

```bash
kubectl port-forward service/prometheus-service 9090:9090
kubectl port-forward service/grafana-service 3000:3000
```

---

## Verificando Logs específicos via kubectl

Os logs também aparecem no `stdout` de cada pod (Serilog Console sink), úteis para debug local:

```bash
kubectl logs deployment/users-api
kubectl logs deployment/notifications-api
kubectl logs deployment/catalog-api
kubectl logs deployment/payments-api
```

## Observações

Após a inicialização do ambiente, os microserviços estarão disponíveis para uso conforme a necessidade de interação e testes.

Para mais detalhes sobre cada serviço, consulte os respectivos arquivos `README.md` de cada repositório.
