#!/bin/bash
# DEV291 - Failure Fix 3: Patroni Fails to Start After Restore (System ID Mismatch)
# Clears stale etcd metadata so Patroni can re-bootstrap with the restored system ID
# WARNING: Only run this in a sandbox/restore scenario, NOT on a live production cluster

# Check the current system identifier in the restored data directory
sudo -u postgres /usr/lib/postgresql/15/bin/pg_controldata \
  /var/lib/postgresql/15/main | grep 'system identifier'

# Check what Patroni has registered in etcd
etcdctl get /service/demo/config --print-value-only

# Remove the stale Patroni cluster metadata from etcd
# WARNING: Only do this in a sandbox / restore scenario
etcdctl del /service/demo --prefix

# Restart Patroni — it will now bootstrap using the restored system identifier
sudo systemctl start patroni

# Watch the logs
journalctl -u patroni -f --no-pager | head -30
