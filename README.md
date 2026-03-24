
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
\User> kubectl apply -f k8s/
\Notification> kubectl apply -f k8s/
\FIAP.Catalog> kubectl apply -f k8s/
\FIAP.Payments> kubectl apply -f k8s/
```

Esse processo também deve ser feito no projeto raiz **FIAP.Microservicos**, responsável por iniciar serviços compartilhados, como o **RabbitMQ**.

```bash
\FIAP.Microservicos> kubectl apply -f k8s/
```

## Acesso às APIs

Atualmente, estamos utilizando `port-forward` para acessar as APIs que necessitam de interação.
Para cada Microservicos que for usar o `port-forward` deverá ser aaberto um novo CMD.

### Users API

```bash
kubectl port-forward service/users-api-service 8083:80
```

### Catalog API

```bash
kubectl port-forward service/catalog-api-service 8080:80
```

### Rabbit - caso onde é necessario verificar a fila. 

```bash
kubectl port-forward service/rabbitmq-service 15672:15672
```

## Exemplo de como acessar o port-forward

http://localhost:8080/index.html -- Catalog
http://localhost:8083/index.html -- User
http://localhost:15672/ -- RabbitMQ , Acesso: guest/guest


## Verificando Logs de evento após a CRIAÇÃO e COMPRA

Para verificar os LOGS de saida de criação de um novo USER e da COMPRA REALIZADA sendo sucesso ou não sucesso pode ser visto pelo comando

```bash
kubectl logs deployment/notifications-api
```

## Observações

Após a inicialização do ambiente, os microserviços estarão disponíveis para uso conforme a necessidade de interação e testes.

Para mais detalhes sobre cada serviço, consulte os respectivos arquivos `README.md` de cada repositório.


