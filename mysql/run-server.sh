#!/bin/bash

mkdir -p /run/mysqld
mkdir -p /var/lib/mysql-files

if [ -d /app/mysql ]; then
  echo "[i] MySQL directory already present, skipping initialization."
else
  echo "[i] MySQL data directory not found, initializing DB."

  /usr/sbin/mysqld --user=root --initialize-insecure --verbose=0
fi

exec /usr/sbin/mysqld --user=root --console
