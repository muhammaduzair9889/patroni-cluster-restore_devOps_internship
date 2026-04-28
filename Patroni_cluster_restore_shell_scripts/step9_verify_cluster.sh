#!/bin/bash
# DEV291 - Step 9: Verify Cluster Health
# Checks cluster topology, data integrity, and replication status

# Check cluster topology
patronictl -c /etc/patroni/patroni.yml list

# Connect to the restored cluster and verify data integrity
sudo -u postgres psql -c "SELECT version();"

# Verify row counts in a key table to confirm data integrity
# Replace 'yourdb' and 'orders' with your actual database and table names
sudo -u postgres psql -d yourdb -c "SELECT COUNT(*) FROM orders;"
