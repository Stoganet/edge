FROM caddy:2.11.4-builder-alpine@sha256:c2433c74c0648b47d8a844ff1792661f93996c553687101bbdf89c63a09dccef AS builder
RUN xcaddy build --with github.com/mholt/caddy-ratelimit

FROM caddy:2.11.4-alpine@sha256:77c07d5ebfa5be9fd6c820d2094ae662c9e7eeb9bf98346b7f639900263ee2a2
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
