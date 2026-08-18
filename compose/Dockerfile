FROM caddy:2.11.4-builder-alpine@sha256:0ff10d4b83af453e5526b1c3cd7ae43396832aa8a2a55311d624f6812b33767d AS builder
RUN xcaddy build --with github.com/mholt/caddy-ratelimit

FROM caddy:2.11.4-alpine@sha256:5f5c8640aae01df9654968d946d8f1a56c497f1dd5c5cda4cf95ab7c14d58648
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
