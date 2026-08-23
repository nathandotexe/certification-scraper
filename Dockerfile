# © AngelaMos | 2026
# Dockerfile

FROM elixir:1.18-otp-27-alpine AS build

WORKDIR /app
ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

COPY lib lib
RUN mix compile && mix escript.build

FROM erlang:27-alpine

RUN apk add --no-cache ca-certificates

WORKDIR /app

COPY --from=build /app/certscout ./certscout
COPY lists lists
RUN chmod +x ./certscout

ENTRYPOINT ["./certscout"]
CMD ["--sources", "greenhouse"]
