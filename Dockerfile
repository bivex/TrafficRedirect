# Multi-stage production build for Traffic Redirect Engine
FROM elixir:alpine AS builder

RUN apk add --no-cache build-base git

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

COPY config config
COPY lib lib

RUN mix compile
RUN mix release

# Lean production image
FROM alpine:latest AS runner

RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

ENV MIX_ENV=prod
ENV PORT=4000

COPY --from=builder /app/_build/prod/rel/traffic_redirect ./

EXPOSE 4000

CMD ["bin/traffic_redirect", "start"]
