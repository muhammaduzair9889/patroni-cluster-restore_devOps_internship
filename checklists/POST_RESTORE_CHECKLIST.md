# POST-RESTORE CHECKLIST

**Use this checklist AFTER restore completes**

Run this immediately after the restore finishes to verify success.

## Cluster Status Verification

- [ ] All 3 nodes are online: `patronictl list`
  - PRIMARY node shows "L" (Leader): ✓
  - REPLICA-1 shows "F" (Follower): ✓
  - REPLICA-2 shows "F" (Follower): ✓
  - All nodes show "running": ✓

- [ ] No split-brain situation: `patronictl list` shows only 1 PRIMARY: ✓

## PostgreSQL Verification

- [ ] PostgreSQL started successfully on all nodes
  - Primary: `systemctl status postgresql@15-main` = active ✓
  - Replica-1: `systemctl status postgresql@15-main` = active ✓
  - Replica-2: `systemctl status postgresql@15-main` = active ✓

- [ ] No PostgreSQL errors in logs:
  ```bash
  tail -20 /var/log/postgresql/postgresql-15-main.log | grep -i error
  ```
  - Should show no FATAL/ERROR messages ✓

- [ ] Database is accessible from primary:
  ```bash
  psql -U postgres -c "SELECT version();"
  ```
  - Returns PostgreSQL version ✓

## Replication Verification

- [ ] Replicas are connected to primary:
  ```bash
  psql -c "SELECT client_addr, state FROM pg_stat_replication;"
  ```
  - Shows 2 replicas ✓
  - Both show state = "streaming" ✓

- [ ] Replication lag is minimal:
  ```bash
  psql -c "SELECT client_addr, write_lag, flush_lag, replay_lag FROM pg_stat_replication;"
  ```
  - All lags < 1 second: ✓

- [ ] Standby feedback working (if enabled):
  ```bash
  psql -c "SELECT * FROM pg_stat_replication WHERE client_addr='replica-1';"
  ```
  - Shows flush_lsn and replay_lsn: ✓

## Data Integrity

- [ ] Database accepts new writes:
  ```bash
  psql -c "INSERT INTO test_table VALUES (1, 'test');"
  psql -c "SELECT COUNT(*) FROM test_table;"
  ```
  - Insert succeeds ✓
  - Query returns rows ✓

- [ ] Data replicated to replicas:
  ```bash
  # Run on replica
  psql -c "SELECT COUNT(*) FROM test_table;" | grep -q "1" && echo "Data replicated"
  ```
  - Query returns same count on replica ✓

- [ ] No data corruption detected:
  ```bash
  psql -c "CREATE EXTENSION IF NOT EXISTS amcheck;"
  psql -c "SELECT heap_force_kill('table'::regclass, '(0,1)'::tid); " 2>/dev/null || echo "No corruption"
  ```
  - No corruption errors ✓

- [ ] System ID is consistent:
  ```bash
  sudo -u postgres pg_controldata /var/lib/postgresql/15/main | grep "Database system identifier"
  ```
  - Verify across all 3 nodes - all match: ✓

## Patroni Cluster State

- [ ] Patroni is managing cluster correctly:
  ```bash
  patronictl list
  ```
  - Shows healthy cluster topology ✓
  - All nodes managed by Patroni ✓

- [ ] etcd cluster is healthy:
  ```bash
  sudo etcdctl endpoint health
  ```
  - All members healthy ✓

- [ ] etcd has correct cluster data:
  ```bash
  sudo etcdctl ls /service/patroni/
  ```
  - Shows cluster key and leader info ✓

## Network & Connectivity

- [ ] Primary to replicas: All connected
  ```bash
  nc -zv replica-1 5432 && nc -zv replica-2 5432 && echo "Network OK"
  ```
  - Both connections successful ✓

- [ ] All nodes can reach backup repository:
  ```bash
  ssh replica-1 "pgbackrest info" && echo "Repo accessible"
  ```
  - Command succeeds on all nodes ✓

## Backup & Recovery Capability

- [ ] WAL recovery completed successfully:
  ```bash
  psql -c "SELECT pg_current_wal_lsn();"
  ```
  - Returns valid WAL position ✓

- [ ] WAL archiving working:
  ```bash
  psql -c "SHOW archive_command;"
  ```
  - Shows valid archive command ✓

- [ ] Timeline history is consistent:
  ```bash
  ls -la /var/lib/postgresql/15/main/pg_wal/timeline_history
  ```
  - Shows timeline history files ✓

## Performance Verification

- [ ] Measure data restore timing:
  - Start time (noted before): `_____`
  - End time (now): `_____`
  - Restore duration: `_____` minutes
  - Expected: 20-30 min (database size dependent)

- [ ] Database queries execute at reasonable speed:
  ```bash
  psql -c "EXPLAIN ANALYZE SELECT COUNT(*) FROM your_table;"
  ```
  - Query plan shows good performance ✓
  - No sequential scans on large tables ✓

## Application Connectivity

- [ ] Application connection string works:
  ```bash
  psql -h primary -U app_user -d app_database -c "SELECT 1;"
  ```
  - Connection successful ✓
  - Query returns result ✓

- [ ] Read-only replica connection works (if configured):
  ```bash
  psql -h replica-1 -U readonly_user -d app_database -c "SELECT COUNT(*) FROM your_table;"
  ```
  - Connection successful ✓
  - Read-only verified ✓

## Log File Review

- [ ] pgBackRest logs show success:
  ```bash
  tail -50 /var/log/pgbackrest/demo-restore.log | grep -i "completed\|error"
  ```
  - Shows "restore completed" ✓
  - No FATAL errors ✓

- [ ] PostgreSQL startup successful:
  ```bash
  grep -i "redo done\|database system is ready" /var/log/postgresql/postgresql-15-main.log
  ```
  - Shows successful startup ✓

- [ ] Patroni startup successful:
  ```bash
  sudo journalctl -u patroni -n 50 | grep -i "initialized\|elected"
  ```
  - Shows cluster initialized/elected ✓

## Final Verification

- [ ] All nodes accessible via SSH: ✓
- [ ] Cluster shows all 3 nodes: ✓
- [ ] Primary is elected and active: ✓
- [ ] Replicas connected and syncing: ✓
- [ ] Data is accessible: ✓
- [ ] No errors in any logs: ✓
- [ ] Network connectivity verified: ✓

## Clean-Up Tasks

- [ ] Remove temporary test data: `DELETE FROM test_table;`
- [ ] Clear restore logs if desired
- [ ] Update documentation with actual timings
- [ ] Notify stakeholders of successful restore
- [ ] Document any issues found

## Final Sign-Off

- Verification started at: `_____`
- Verification completed at: `_____`
- Total verification time: `_____` minutes
- Overall result: ☐ PASS ☐ FAIL

- Verified by: `___________________`
- Date: `___________________`
- Issues found: ☐ None ☐ Minor ☐ Major

**If FAIL:** Stop here. Investigate and resolve issues before completing.

**If PASS:** Restore is successful! Document completion and notify stakeholders.

---

## Issues Found?

If any item above fails:

1. Note the issue
2. Check [../failure-analysis/](../failure-analysis/) for similar errors
3. Review [../procedures/](../procedures/) for step details
4. Execute the fix
5. Verify the item again
6. Mark as resolved

---

**Next Steps:**

- [ ] Update status in [HEALTH_CHECK_CHECKLIST.md](HEALTH_CHECK_CHECKLIST.md)
- [ ] Begin daily health monitoring
- [ ] Schedule next monthly restore drill
- [ ] Review [../LESSONS_LEARNED.md](../LESSONS_LEARNED.md) for insights

---

**Documentation:** [../README.md](../README.md) | [../LESSONS_LEARNED.md](../LESSONS_LEARNED.md)
