#!/bin/bash
# DEV291 - Step 6: Fix File Permissions
# Ensures correct ownership and permissions on the data directory

# Ensure correct ownership recursively
sudo chown -R postgres:postgres /var/lib/postgresql/15/main

# Ensure correct permissions on the data directory
sudo chmod 700 /var/lib/postgresql/15/main

# Verify
stat /var/lib/postgresql/15/main
