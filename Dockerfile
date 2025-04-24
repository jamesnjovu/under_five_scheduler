# Build arguments
ARG ELIXIR_VERSION=1.14.5
ARG OTP_VERSION=26.2.2
ARG DEBIAN_VERSION=bullseye-20240130-slim
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"

# Assets builder stage
FROM node:20.18 as assets_builder
WORKDIR /app/assets
COPY assets .
RUN npm install --omit=dev

# App builder stage
FROM ${BUILDER_IMAGE} as app_builder

# Install build dependencies with standard apt commands
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Set memory-related environment variables for mix and erlang
ENV ERL_FLAGS="+MBas aoffcbf +MHas aoffcbf +MBlmbcs 512 +MHlmbcs 512 +MMmcs 30"
ENV MIX_ENV=prod

# Install hex + rebar with retry logic
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy only necessary files for dependency installation
COPY mix.exs ./
COPY config config

# Get and compile dependencies with memory optimization
RUN mix deps.get --only $MIX_ENV && \
    mix deps.compile --no-debug-info

# Copy application files
COPY priv priv
COPY lib lib
COPY --from=assets_builder /app/assets ./assets

# Compile assets
RUN mix assets.deploy

# Compile the release with memory optimization
RUN mix compile --no-debug-info

# Copy runtime config and release files
COPY config/runtime.exs config/

# Create release with memory optimization
RUN mix release --overwrite

# Final stage - Use Debian Bullseye
FROM debian:${DEBIAN_VERSION}

ENV DEBIAN_FRONTEND=noninteractive

# Set the locale
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Install runtime dependencies including wkhtmltopdf
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    openssl \
    ca-certificates \
    inotify-tools \
    wkhtmltopdf \
    locales \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN chown nobody /app

# Environment variables
ENV MIX_ENV="prod"

# Remove hardcoded database URLs and secrets - these should be provided at runtime
# through Docker environment variables or secrets management

COPY --from=app_builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/under_five_rel ./

USER nobody
# Use ENTRYPOINT to ensure environment variables are loaded
ENTRYPOINT ["/bin/bash", "-c"]
CMD ["exec /app/bin/under_five_rel start --erl '+A 8' --name pbs_gw_client@sms.probasegroup.com --cookie pbs_gw"]
