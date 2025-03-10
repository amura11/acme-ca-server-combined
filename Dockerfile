ARG UPSTREAM_TAG=latest
FROM knrdl/acme-ca-server:${UPSTREAM_TAG}

# Switch back to root
USER root

# Install PostgreSQL and dependencies
RUN apk update && apk add --no-cache \
    postgresql \
    postgresql-client \
    postgresql-dev \
    build-base \
    libpq-dev \
    su-exec \
    shadow

# Adjust existing appuser or create if not exists
RUN if ! id appuser >/dev/null 2>&1; then \
      addgroup -g 1000 appuser && \
      adduser -u 1000 -G appuser --no-create-home --disabled-password appuser; \
    fi

# Create data directories
RUN mkdir -p /data/db && chown -R appuser:appuser /data

# Initialize PostgreSQL database
RUN su-exec appuser initdb -D /data/db && \
    echo "listen_addresses='localhost'" >> /data/db/postgresql.conf

# Volume for persistent data
VOLUME ["/data"]

# Default environment variables
ENV PUID=99 \
    PGID=100 \
    UMASK=022 \
    DB_USER=postgres \
    DB_PASSWORD=p0stgr3sp@ssw0rd \
    DB_NAME=acme-ca \
    EXTERNAL_URL=https://external.url

# Copy and set entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /app

USER appuser

ENTRYPOINT ["/entrypoint.sh"]
