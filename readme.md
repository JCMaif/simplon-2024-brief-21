# Brief 21 - Déploiement d'une API en Rust avec Docker et CI/CD



## Préparation

On a un workspace de travail créé automatiquement au lancement du brief. Il comporte le clone du repository d'origine.
* Création d'un fork sur github : [fork](https://github.com/JCMaif/simplon-2024-brief-21)
* modification de l'adresse de fetch et push du repository du workspace => objectif : changer l'adresse de `origin`

```bash
git remote -v
git remote set-url origin https://github.com/JCMaif/simplon-2024-brief-21

//vérification :
git remote -v

root ➜ /workspaces/simplon-2024-brief-21 (main) $ git remote -v
origin  https://github.com/JCMaif/simplon-2024-brief-21 (fetch)
origin  https://github.com/JCMaif/simplon-2024-brief-21 (push)
```

## Application

L'application est en rust. Après recherches, je comprends que :
- démarrer un projet : `cargo run`
- build un projet : `cargo build --release` crée un build et le place dans target/release
- dans les sources `src/bin.rs` on se rend compte qu'il y a plusieurs variables d'environnement utilisées pour la connexion à la base de données et les ports d'écoute. Je vais donc renseigner ces variables d'environnement dans docker.
- dans Cargo.toml, on voit le nom de l'application (`shop`) et les bins (`shop_bin`), qu'on utilisera dans le Dockerfile

## Dockerfile

Après avoir pris connaissance des points précédents, je peux écrire le Dockerfile :

```dockerfile
FROM rust:1.87-slim AS builder
WORKDIR /usr/src/shop
COPY . .
RUN rustup default nightly && rustup update
RUN cargo build --release
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y build-essential && rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/src/shop/target/release/shop_bin /usr/local/bin/shop
CMD ["shop"]
```
avec :
- `rust:1.87-slim` : version préconisée par la doc de rust sur docker.hub
- `RUN rustup default nightly && rustup update` : nécessaire pour utiliser une version stable, car l'application a été développée avec une version nightly, ce qui n'est pas utilisable dans docker

## docker-compose.yml

```yml
services:
  api:
    image: registry.nocturlab.fr/jc1932/brief21
    restart: unless-stopped
    depends_on:
      - db
    networks:
      - traefik_default
      - api
    labels:
     - "traefik.enable=true"
     - "traefik.http.routers.rust-api.rule=Host(`jaudebert.nocturlab.fr`)"
     - "traefik.http.services.rust-api.loadbalancer.server.port=80"

    environment:
      POSTGRES_HOST: db:5432
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: app
      HOST: 0.0.0.0
      PORT: 80

  db:
    image: postgres:latest
    restart: always
    environment:
      POSTGRES_DB: app
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks:
      - api

volumes:
  pgdata:

networks:
  traefik_default:
    external: true
  api:
```

## Commandes docker

Dans mon espace de travail (workspace) :
* build : `docker build -t registry.nocturlab.fr/jc1932/brief21 .`
* push sur le registry : `docker push registry.nocturlab.fr/jc1932/brief21`

Dans le server (connecté en ssh) :
* aller dans le répertoire de l'appli : `cd simplon-2024-brief-21`
* au premier `docker compose up -d`, l'image `registry.nocturlab.fr/jc1932/brief21` sera téléchargée. A chaque modification ultérieure du build, il faudra aller la rechercher avec `docker pull registry.nocturlab.fr/jc1932/brief21`

## Accès à l'application

Dans le navigateur, `https:jaudebert.nocturlab.fr` affiche la page de l'application grâce au reverse proxy traefik.
