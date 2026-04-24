# Step 9: Verify Cluster Health

**Purpose:** Final verification that cluster is fully restored and operational.

**Estimated Time:** 3 minutes

**Difficulty:** Easy

## Overview

Comprehensive verification checks:
1. All 3 nodes online and running
2. Primary elected (Leader role)
3. Replicas connected (Follower role)
4. Replication streaming actively
5. Zero data loss
6. Data integrity confirmed
7. Ready for normal operations

## Prerequisites

- Patroni started on all nodes (Step 8 complete)
- Cluster stabilized (30+ seconds passed)
- All nodes showing status in patronictl

## Procedure

### 9.1: Check Cluster Status with patronictl

```bash
# Check cluster membership and health
patronictl list

# Expected output:
# +-----------+----------+-----+---------+
# | Member    | Host     | Role| Status  |
# +-----------+----------+-----+---------+
# | primary   | 10.0.1.1 | L   | running |
# | replica-1 | 10.0.1.2 | F   | running |
# | replica-2 | 10.0.1.3 | F   | running |
# +-----------+----------+-----+---------+

# Verify:
# - All 3 members present
# - One "L" (Leader) - should be "primary"
# - Two "F" (Followers) - should be "replica-1" and "replica-2"
# - All status = "running"
```

### 9.2: Verify Primary is Correct

```bash
# Check which node is primary
patronictl list | grep "L"

# Expected: primary node shows "L" for Leader
# If wrong node elected: Check priority settings in /etc/patroni/patroni.yml
```

### 9.3: Check Replication Status

```bash
# Connect to primary and check connected replicas
sudo -u postgres psql -c "SELECT application_name, client_addr, state, replay_lag FROM pg_stat_replication;"

# Expected output:
# application_name | client_addr | state      | replay_lag
# -----------------+-------------+------------+----------
# replica-1        | 10.0.1.2    | streaming  | (null)
# replica-2        | 10.0.1.3    | streaming  | (null)

# Verify:
# - 2 replicas connected
# - state = "streaming" (not "catchup")
# - replay_lag = null or < 1 second
```

### 9.4: Check Synchronous Replication Status

```bash
# Verify synchronous replication is working
sudo -u postgres psql -c "SHOW synchronous_commit;"

# Expected: on or remote_apply (depending on config)
# This ensures replicas get changes before primary confirms to client
```

### 9.5: Verify Replication Slots

```bash
# Check replication slots (if configured)
sudo -u postgres psql -c "SELECT slot_name, active, restart_lsn FROM pg_replication_slots;"

# Expected: One row per replica with active=true
# (May be empty if slots not configured - that's OK)
```

### 9.6: Check Database Integrity

```bash
# List all databases
sudo -u postgres psql -c "SELECT datname FROM pg_database WHERE datname NOT IN ('template0', 'template1', 'postgres') ORDER BY datname;"

# Expected: Your production databases listed

# Count tables in your main database
sudo -u postgres psql -d your_database_name -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog', 'information_schema');"

# Expected: Your expected table count (> 0)
```

### 9.7: Verify No Data Loss

```bash
# Check last transaction timestamp
sudo -u postgres psql -c "SELECT max(xmin::text::bigint) as latest_txid FROM pg_database;"

# Check recovery end timestamp
sudo -u postgres psql -c "SELECT pg_postmaster_start_time();"

# Check backup recovery point
sudo -u postgres psql -c "SELECT * FROM pg_control_recovery();"

# These confirm database recovered to expected point
```

### 9.8: Verify System Identifier Consistency

```bash
# Get system ID (should be same on all nodes)
sudo -u postgres pg_controldata /var/lib/postgresql/15/main | grep "Database system identifier"

# Do this on all 3 nodes and verify they match
ssh replica-1 "sudo -u postgres pg_controldata /var/lib/postgresql/15/main | grep 'Database system identifier'"
ssh replica-2 "sudo -u postgres pg_controldata /var/lib/postgresql/15/main | grep 'Database system identifier'"

# Expected: Same system ID on all 3 nodes
```

### 9.9: Full Cluster Verification Command

```bash
# Run all checks at once (execute on primary)
sudo -u postgres psql << 'EOF'
\echo '=== Cluster Status ==='
SELECT current_database(), current_user, now();

\echo '=== Replication Status ==='
SELECT application_name, client_addr, state, replay_lag 
FROM pg_stat_replication;

\echo '=== Databases ==='
SELECT datname, pg_size_pretty(pg_database_size(datname)) 
FROM pg_database 
WHERE datname NOT IN ('template0', 'template1') 
ORDER BY pg_database_size(datname) DESC;

\echo '=== Table Count ==='
SELECT COUNT(*) FROM information_schema.tables 
WHERE table_schema NOT IN ('pg_catalog', 'information_schema');

\echo '=== Synchronous Status ==='
SHOW synchronous_commit;

\echo '=== All Checks Complete ==='
EOF
```

## Verification Checklist

Complete ALL of these before declaring restoration successful:

- [ ] patronictl list shows all 3 nodes
- [ ] One primary with "L" role
- [ ] Two replicas with "F" role
- [ ] All nodes status: "running"
- [ ] 2 replicas connected (pg_stat_replication)
- [ ] Replication state: "streaming"
- [ ] Replay lag: null or < 1 second
- [ ] Synchronous commit: enabled
- [ ] Database integrity verified
- [ ] System identifiers match (all nodes)
- [ ] No errors in logs
- [ ] Application can connect

## Quick Health Check Script

```bash
#!/bin/bash

echo "=== Cluster Health Check ==="
echo "Time: $(date)"
echo

echo "1. Cluster Status:"
patronictl list
echo

echo "2. Replication:"
sudo -u postgres psql -c "SELECT application_name, state, replay_lag FROM pg_stat_replication;"
echo

echo "3. Database List:"
sudo -u postgres psql -c "SELECT datname FROM pg_database WHERE datname !~ '^template' ORDER BY datname;"
echo

echo "4. System Identifier (should match all nodes):"
sudo -u postgres pg_controldata /var/lib/postgresql/15/main | grep "Database system identifier"
echo

echo "5. Errors in Logs:"
sudo tail -10 /var/log/postgresql/postgresql-15-main.log | grep ERROR || echo "No errors"
echo

echo "=== Health Check Complete ==="
```

## Common Issues & Fixes

### Issue 1: Replicas not connected

```bash
# Wait longer for replication to establish
sleep 30
sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"

# If still not connected:
# Check replica logs
sudo tail -50 /var/log/postgresql/postgresql-15-main.log

# Common causes:
# - Network connectivity: ping replica-1
# - PostgreSQL not running: systemctl status postgresql
# - Replication role not configured: Check postgresql.conf
```

### Issue 2: System identifiers don't match

```bash
# This is critical - restore may have gone wrong
# Get IDs from all nodes
ssh primary "sudo -u postgres pg_controldata /var/lib/postgresql/15/main | grep 'Database system identifier'"
ssh replica-1 "sudo -u postgres pg_controldata /var/lib/postgresql/15/main | grep 'Database system identifier'"
ssh replica-2 "sudo -u postgres pg_controldata /var/lib/postgresql/15/main | grep 'Database system identifier'"

# If primary differs from replicas: Need to re-restore replicas
# Follow [03_CLEAN_DATA_DIR.md](03_CLEAN_DATA_DIR.md) and [04_RUN_RESTORE.md](04_RUN_RESTORE.md) on replicas

# If all differ: Full cluster restore may be needed
```

### Issue 3: High replication lag (> 10 seconds)

```bash
# Database is write-heavy, catching up
# Wait for lag to decrease
watch -n 5 'psql -c "SELECT application_name, replay_lag FROM pg_stat_replication;"'

# If lag doesn't decrease after 5 minutes:
# Check primary write load
top -n 1 | head -15

# Check network between nodes
iftop -i eth0
```

### Issue 4: Primary wrongly elected (should be "primary" node)

```bash
# Check Patroni priorities in config
sudo cat /etc/patroni/patroni.yml | grep -A 3 "postgresql:"

# If another node was elected primary:
# You can failover back:
patronictl failover

# Choose to promote "primary" node back to primary
```

### Issue 5: Tables/Data missing

```bash
# Verify restore actually copied data
sudo du -sh /var/lib/postgresql/15/main/

# Should be ~50GB (your database size)

# If < 10GB: Restore incomplete, must retry from Step 4

# Check if specific tables exist
sudo -u postgres psql -d your_db -c "\dt"

# If tables missing: Restore to wrong point, verify backup had data
```

## Performance Verification (Optional)

```bash
# Run a test query to verify query performance
time sudo -u postgres psql -d your_db -c "SELECT COUNT(*) FROM your_largest_table;"

# Compare with pre-failure performance
# Should be similar if data integrity is good
```

## Application Testing (Optional but Recommended)

```bash
# Before putting back in production, test with application
# Temporarily connect app to restored cluster
# Run sanity checks:
# 1. Read queries work
# 2. Write queries work
# 3. Replication is streaming changes
# 4. No unexpected errors

# Monitor for 5-10 minutes before declaring success
```

## Summary Checklist for Restoration Success

✅ **All 3 nodes operational**
- Primary elected and accepting connections
- Replicas connected and replicating
- All services: active (running)

✅ **Data Integrity**
- Expected databases exist
- Expected tables exist
- System identifiers match
- Data is queryable

✅ **Replication Health**
- 2 replicas connected
- Replication state: streaming
- Lag < 1 second
- No connection errors

✅ **Logs Clean**
- No critical errors
- No permission issues
- No corruption messages

✅ **Ready for Production**
- Cluster fully operational
- No known issues
- Backup procedures verified

## Next Steps

1. **Monitor cluster for 1 hour** - Watch for any issues
2. **Run backup verification** - Ensure backups still work
3. **Test failover** - Verify leader election still works
4. **Document the restore** - Record what happened, time taken
5. **Return to normal operations** - Restore production traffic

## Final Notes

Congratulations! Your cluster has been successfully restored from backup. The 9-step process is complete. 

- Total time: 20-30 minutes
- Data integrity: Verified
- All nodes: Operational
- Replication: Active
- Ready for: Production use

---

**Troubleshooting:** See [../failure-analysis/](../failure-analysis/) for any issues encountered

**Next:** Monitor cluster and prepare for [../LESSONS_LEARNED.md](../LESSONS_LEARNED.md)
