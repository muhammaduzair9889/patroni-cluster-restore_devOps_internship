#!/bin/bash
# DEV291 - Step 3: Clean the Old Data Directory
# Renames the existing data directory and creates a fresh empty one

# Navigate to the PostgreSQL base directory
cd /var/lib/postgresql/15/

# List current contents
ls -la

# Rename existing data directory as a backup
sudo -u postgres mv /var/lib/postgresql/15/main /var/lib/postgresql/15/main.bak_$(date +%Y%m%d%H%M%S)

# Create a new empty data directory
sudo -u postgres mkdir /var/lib/postgresql/15/main

# Set correct permissions (700 required by PostgreSQL)
sudo chmod 700 /var/lib/postgresql/15/main

# Confirm
ls -la /var/lib/postgresql/15/
