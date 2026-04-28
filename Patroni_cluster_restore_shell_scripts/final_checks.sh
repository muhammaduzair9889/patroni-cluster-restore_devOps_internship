#!/bin/bash
# DEV291 - Final Outcome: Data Integrity and Replication Checks
# Run after full restore to confirm cluster and data health

# Check final cluster state
patronictl -c /etc/patroni/patroni.yml list

# Run pgBackRest stanza-check to confirm archive integrity
sudo -u postgres pgbackrest --stanza=demo check

# Verify replication is healthy from the primary
sudo -u postgres psql -c "SELECT client_addr, state, sent_lsn, write_lsn, flush_lsn, replay_lsn, sync_state FROM pg_stat_replication;"
