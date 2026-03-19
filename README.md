# FIAP.Microservicos

Repositório responsável pela orquestração dos microserviços do projeto CloudGames, centralizando a execução dos serviços via Docker Compose.

## Estrutura do projeto

Este repositório utiliza submodules para referenciar os microserviços separados em repositórios independentes.

### Repositórios utilizados

- [FIAP.Payments](https://github.com/LucianoDSMiranda/FIAP.Payments)
- [FIAP.Catalog](https://github.com/LucianoDSMiranda/FIAP.Catalog)
- [cloudgames-notifications-api](https://github.com/LeandroLeeh32/cloudgames-notifications-api)
- [cloudgames-users-api](https://github.com/LeandroLeeh32/cloudgames-users-api)

## Estrutura esperada

FIAP.Microservicos/
├── docker-compose.yml
├── README.md
├── FIAP.Payments/
├── FIAP.Catalog/
├── Notification/
└── User/


### Clonando o projeto

Como este repositório utiliza submodules, recomenda-se clonar com o comando abaixo:

```bash
git clone --recurse-submodules https://github.com/LucianoDSMiranda/FIAP.Microservicos.git

