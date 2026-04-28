#!/bin/bash
# DEV291 - Step 7: Start PostgreSQL for WAL Replay (Manual Mode)
# Starts PostgreSQL directly to complete WAL recovery, then promotes to primary

# Start PostgreSQL directly (not via Patroni)
sudo -u postgres /usr/lib/postgresql/15/bin/pg_ctl start \
  -D /var/lib/postgresql/15/main \
  -l /var/log/postgresql/postgresql-15-main.log

# Promote PostgreSQL to primary (after WAL replay completes)
sudo -u postgres /usr/lib/postgresql/15/bin/pg_ctl promote \
  -D /var/lib/postgresql/15/main
