# HEALTH CHECK CHECKLIST - Daily Monitoring

**Use this checklist DAILY to verify cluster health**

This is a quick 5-minute check to verify the cluster is functioning properly.

## Quick Status Check (1 minute)

```bash
patronictl list
```

Expected output:
```
+ Cluster: demo (7123456789456123456) ----+----+-----------+
| Member  | Host       | Role    | State   | TL | Lag |
+---------+------------+---------+---------+----+-----+
| primary | 10.0.0.1   | Leader  | running |  1 | 0B  |
| replica-1 | 10.0.0.2 | Replica | running |  1 | 0B  |
| replica-2 | 10.0.0.3 | Replica | running |  1 | 0B  |
+----+---------+-----------+
```

Check these items:

- [ ] **All 3 members present:** primary, replica-1, replica-2
- [ ] **Primary has "Leader" role:** ✓
- [ ] **Both replicas have "Replica" role:** ✓
- [ ] **All show "running" state:** ✓
- [ ] **Timeline (TL) is same on all nodes:** ✓
- [ ] **Lag is 0B (or < 100MB):** ✓

**If ANY check fails:** See [Troubleshooting](#troubleshooting) below

## Detailed Status Check (2 minutes)

```bash
# Check PostgreSQL replication
psql -c "SELECT client_addr, state FROM pg_stat_replication;"
```

Expected output:
```
  client_addr   |   state   
----------------+-----------
 10.0.0.2       | streaming
 10.0.0.3       | streaming
(2 rows)
```

Check these items:

- [ ] **2 rows returned (both replicas):** ✓
- [ ] **All show state = "streaming":** ✓
- [ ] **No "catchup" or other states:** ✓

```bash
# Check replication lag
psql -c "SELECT client_addr, replay_lag FROM pg_stat_replication;"
```

Expected output:
```
  client_addr   | replay_lag 
----------------+------------
 10.0.0.2       | 00:00:00.123456
 10.0.0.3       | 00:00:00.234567
(2 rows)
```

Check these items:

- [ ] **All replay_lag < 1 second (1000ms):** ✓
- [ ] **No "null" values:** ✓

## Log Check (1 minute)

```bash
# Check for errors in past hour
tail -100 /var/log/postgresql/postgresql-15-main.log | grep -i "error\|fatal\|panic"
```

Expected output: Empty (no errors)

- [ ] **No ERROR lines:** ✓
- [ ] **No FATAL lines:** ✓
- [ ] **No PANIC lines:** ✓

```bash
# Check Patroni logs
sudo journalctl -u patroni --since "1 hour ago" | grep -i "error\|failure"
```

Expected output: Empty (no errors)

- [ ] **No error messages:** ✓
- [ ] **No failures:** ✓

## Disk Space Check (1 minute)

```bash
# Check primary data directory
df -h /var/lib/postgresql | tail -1
```

Expected:
- [ ] **Available space > 20% of partition:** ✓
- [ ] **No "100%" or "99%" used:** ✓

```bash
# Check backup repository
df -h /mnt/pgbackrest-repo | tail -1
```

Expected:
- [ ] **Available space > 10GB:** ✓
- [ ] **Usage < 80%:** ✓

## Connectivity Check (1 minute)

- [ ] Can connect to primary:
  ```bash
  psql -h primary -c "SELECT 1;"
  ```

- [ ] Can connect to replica-1:
  ```bash
  psql -h replica-1 -c "SELECT 1;"
  ```

- [ ] Can connect to replica-2:
  ```bash
  psql -h replica-2 -c "SELECT 1;"
  ```

All three should return `?column?` = 1 with no errors

- [ ] All 3 connections successful: ✓

## Performance Check (1 minute - Optional)

```bash
# Check slow queries
psql -c "SELECT query, calls, total_time, mean_time FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 5;"
```

- [ ] **All queries running < 1 second average:** ✓
- [ ] **No queries with huge total_time:** ✓

## Summary

If ALL items are checked (✓):
```
✓ Cluster is HEALTHY
✓ All nodes operational
✓ Replication working
✓ No errors detected
✓ Disk space sufficient
✓ Performance normal
```

**Status:** ☑ HEALTHY - No action needed

---

## Troubleshooting

### If status shows "unhealthy" or node missing:

```bash
# Check which node is missing
patronictl list

# Try to SSH to missing node
ssh replica-1 "systemctl status postgresql@15-main"

# If PostgreSQL is down, restart it
ssh replica-1 "sudo systemctl start postgresql@15-main"

# If Patroni is down, restart it
ssh replica-1 "sudo systemctl start patroni"

# Wait 30 seconds and check again
sleep 30
patronictl list
```

### If replication lag is high:

```bash
# Check for blocking queries
psql -c "SELECT pid, usename, query FROM pg_stat_activity WHERE state = 'active' LIMIT 5;"

# Check WAL position
psql -c "SELECT pg_current_wal_lsn();"

# Monitor the lag (press Ctrl+C to stop)
watch -n 5 'psql -c "SELECT client_addr, replay_lag FROM pg_stat_replication;"'
```

### If errors appear in logs:

1. Note the error message
2. Check [../failure-analysis/](../failure-analysis/) for similar errors
3. Check procedures for solutions
4. Execute fix
5. Re-run health check

### If disk space is low:

```bash
# Check largest tables
psql -c "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) 
         FROM pg_tables ORDER BY pg_total_relation_size DESC LIMIT 10;"

# Consider archiving old data or running VACUUM
psql -c "VACUUM ANALYZE;"
```

---

## Daily Schedule

Recommended times to run this checklist:

- **08:00 AM:** Start of day check
- **12:00 PM:** Midday check
- **04:00 PM:** Afternoon check (before peak usage)
- **08:00 PM:** End of day check

Or set up automated monitoring with Prometheus + Grafana (see [../IMPROVEMENTS.md](../IMPROVEMENTS.md))

---

## Record Keeping

Keep a log of daily checks:

| Date | Time | Status | Notes |
|------|------|--------|-------|
| 2026-04-01 | 08:00 | ✓ HEALTHY | Normal operation |
| 2026-04-01 | 12:00 | ✓ HEALTHY | Backup running |
| 2026-04-02 | 08:00 | ⚠ WARNING | Lag at 500ms, resolved by 09:00 |

---

**Reference:** [../README.md](../README.md) | [../procedures/09_VERIFY_CLUSTER.md](../procedures/09_VERIFY_CLUSTER.md)
