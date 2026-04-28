#!/bin/bash
# DEV291 - Step 8: Stop PostgreSQL and Hand Control to Patroni
# Stops the manually-started PostgreSQL and lets Patroni take over

# Stop PostgreSQL
sudo -u postgres /usr/lib/postgresql/15/bin/pg_ctl stop \
  -D /var/lib/postgresql/15/main -m fast

# Start Patroni — it will start PostgreSQL under its management
sudo systemctl start patroni

# Check status immediately
sudo systemctl status patroni
