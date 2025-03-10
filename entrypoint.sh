#!/bin/sh

# Adjust UID/GID
groupmod -o -g "$PGID" appuser
usermod -o -u "$PUID" appuser

# Set UMASK
umask "$UMASK"

# Ownership fix
chown -R appuser:appuser /data/db

# Start PostgreSQL
su-exec appuser pg_ctl -D /data/db -l logfile start

# Wait for PostgreSQL startup
sleep 3

# Initialize DB user and database
psql -U appuser -c "CREATE USER \"$DB_USER\" WITH PASSWORD '$DB_PASSWORD';" || true
psql -U appuser -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";" || true

# Set DATABASE_URL for the application
export DATABASE_URL="postgresql://$DB_USER:$DB_PASSWORD@localhost:5432/$DB_NAME"

# Run the passed command as appuser
exec su-exec appuser "$@"
