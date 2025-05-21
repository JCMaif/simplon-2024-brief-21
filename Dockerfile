FROM rust:1.87-slim AS builder
WORKDIR /usr/src/shop
COPY . .
RUN rustup default nightly && rustup update
RUN cargo build --release
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y build-essential && rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/src/shop/target/release/shop_bin /usr/local/bin/shop
CMD ["shop"]