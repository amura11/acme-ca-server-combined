#!/bin/sh

# Adjust UID/GID
groupmod -o -g "$PGID" appuser
usermod -o -u "$PUID" appuser

# Set UMASK
umask "$UMASK"

#  Initialize data folder
mkdir -p /data/db
chown -R appuser:appuser /data/db

# Initialize PSQL directories
mkdir -p /run/postgresql
chown -R appuser:appuser /run/postgresql /data/db

# Initialize database cluster if necessary
if [ ! -f /data/db/PG_VERSION ]; then
    echo "Initializing PostgreSQL data directory..."
    su-exec appuser initdb -D /data/db
    echo "listen_addresses='localhost'" >> /data/db/postgresql.conf
fi

# Start PostgreSQL
su-exec appuser pg_ctl -D /data/db -l /data/db/postgres.log start

# Wait for PostgreSQL to start
TIMEOUT=10
while ! su-exec appuser pg_isready; do
    TIMEOUT=$((TIMEOUT - 1))
    if [ $TIMEOUT -le 0 ]; then
        echo "PostgreSQL did not start within expected time. Exiting."
        exit 1
    fi
    sleep 1
done

# Create DB user and database (if not already created)
echo Setting up $DB_NAME
psql -U appuser -d postgres -tc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1 || \
    psql -U appuser -d postgres -c "CREATE USER \"$DB_USER\" WITH PASSWORD '$DB_PASSWORD';"

psql -U appuser -d postgres -tc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1 || \
    psql -U appuser -d postgres -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"

# Set DATABASE_URL for the application
export DB_DSN="postgresql://$DB_USER:$DB_PASSWORD@localhost:5432/$DB_NAME"

# Run original entrypoint or CMD from upstream
exec su-exec appuser "$@"