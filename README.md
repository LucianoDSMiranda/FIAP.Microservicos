
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
└── User/
````

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
```

## Subindo o ambiente no Kubernetes

Com o Kubernetes iniciado pela interface do Docker Desktop, aplique os arquivos da pasta `k8s` de cada projeto.

Entre na raiz de cada microserviço e execute:

```bash
kubectl apply -f k8s/
```

Esse processo também deve ser feito no projeto raiz **FIAP.Microservicos**, responsável por iniciar serviços compartilhados, como o **RabbitMQ**.

## Acesso às APIs

Atualmente, estamos utilizando `port-forward` para acessar as APIs que necessitam de interação.

### Users API

```bash
kubectl port-forward service/users-api-service 8083:80
```

### Catalog API

```bash
kubectl port-forward service/catalog-api-service 8080:80
```

## Observações

Após a inicialização do ambiente, os microserviços estarão disponíveis para uso conforme a necessidade de interação e testes.

Para mais detalhes sobre cada serviço, consulte os respectivos arquivos `README.md` de cada repositório.


