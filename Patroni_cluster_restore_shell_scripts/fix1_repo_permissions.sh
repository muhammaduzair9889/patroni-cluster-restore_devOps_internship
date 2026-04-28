#!/bin/bash
# DEV291 - Failure Fix 1: Permission Denied on Repository
# Fixes ownership of the pgBackRest repository directory

# Check current ownership of the repository
ls -la /mnt/pgbackrest-repo/

# Recursively change ownership to the postgres user
sudo chown -R postgres:postgres /mnt/pgbackrest-repo

# Confirm
ls -la /mnt/pgbackrest-repo/
