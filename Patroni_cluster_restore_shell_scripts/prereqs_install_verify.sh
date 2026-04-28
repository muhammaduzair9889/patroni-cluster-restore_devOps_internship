#!/bin/bash
# DEV291 - Prerequisites: Install and Verify pgBackRest
# Run on all nodes: pg-node-1, pg-node-2, pg-node-3

# Install pgBackRest on Ubuntu 22.04
sudo apt-get update
sudo apt-get install -y pgbackrest

# Verify installation
pgbackrest version

# Display the pgBackRest configuration (run on pg-node-1)
cat /etc/pgbackrest/pgbackrest.conf

# Check that the backup repository directory is mounted and accessible
ls -lh /mnt/pgbackrest-repo/
