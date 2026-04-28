#!/bin/bash
# DEV291 - Step 2: Stop Patroni Safely on All Nodes
# Run this on each node: pg-node-1, pg-node-2, pg-node-3

# Stop Patroni service on the current node
sudo systemctl stop patroni

# Confirm it is stopped
sudo systemctl status patroni

# Ensure PostgreSQL process is not running independently
sudo -u postgres pg_ctl status -D /var/lib/postgresql/15/main
