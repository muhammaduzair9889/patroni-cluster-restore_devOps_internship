# PRE-RESTORE CHECKLIST

**Use this checklist BEFORE starting any restore procedure**

Run this checklist 1 hour before starting restore. DO NOT PROCEED if any item fails.

## Prerequisites & Access

- [ ] SSH access to PRIMARY node works
- [ ] SSH access to REPLICA-1 node works
- [ ] SSH access to REPLICA-2 node works
- [ ] Can run sudo commands without password (or have password ready)
- [ ] Current user is documented (for audit trail)
- [ ] Time window is clear (no interruptions expected)

## Backup Verification

- [ ] pgBackRest is installed: `pgbackrest version`
- [ ] Backup info command works: `pgbackrest info`
- [ ] At least one backup with status "ok" exists
- [ ] Latest backup is < 7 days old
- [ ] Backup size matches expected database size
- [ ] Stanza name is noted: `[demo]` (lowercase)

## Repository Verification

- [ ] Backup repository is accessible: `ls -la /mnt/pgbackrest-repo/`
- [ ] Repository owner is postgres: `ls -ld /mnt/pgbackrest-repo/`
- [ ] Repository has 0700 permissions
- [ ] Backup files exist: `ls -la /mnt/pgbackrest-repo/demo/backup/`
- [ ] WAL files exist: `ls -la /mnt/pgbackrest-repo/demo/wal/`

## Disk Space Verification

- [ ] Check primary node disk: `df -h /var/lib/postgresql`
  - Need: At least 100GB free
  - Current free: `_____ GB`

- [ ] Check backup repository disk: `df -h /mnt/pgbackrest-repo`
  - Typical: 500GB for backups
  - Current free: `_____ GB`

- [ ] Estimate restore size: `pgbackrest info | grep "database size"`
  - Restore needs this much space
  - Size: `_____ GB`

## Configuration Verification

- [ ] Patroni config exists: `ls -la /etc/patroni/patroni.yml`
- [ ] pgBackRest config exists: `ls -la /etc/pgbackrest/pgbackrest.conf`
- [ ] Stanza name is consistent (lowercase throughout)
- [ ] PostgreSQL config readable: `ls -la /etc/postgresql/15/main/postgresql.conf`

## Network Verification

- [ ] Ping primary node: `ping primary` works
- [ ] Ping replica-1: `ping replica-1` works
- [ ] Ping replica-2: `ping replica-2` works
- [ ] Check network latency: `ping -c 3 primary | grep "rtt"`
  - Should be < 10ms
  - Actual: `_____ ms`

## Service Status Verification

- [ ] Patroni running on primary: `systemctl status patroni`
- [ ] Patroni running on replica-1: `systemctl status patroni`
- [ ] Patroni running on replica-2: `systemctl status patroni`
- [ ] etcd running on all nodes: `systemctl status etcd`
- [ ] PostgreSQL running on all nodes: `systemctl status postgresql@15-main`

## Cluster Health Verification

- [ ] View cluster status: `patronictl list`
  - One PRIMARY with "L" role: ✓
  - Two REPLICAS with "F" role: ✓
  - All status "running": ✓

- [ ] Check replication working: `psql -c "SELECT * FROM pg_stat_replication;"`
  - 2 replicas connected: ✓
  - State = "streaming": ✓
  - Lag < 1 second: ✓

## Data Verification (Optional)

- [ ] Query test table: `psql -c "SELECT COUNT(*) FROM your_table;"`
  - Count: `_____`
  - Query time: `_____` sec

- [ ] Document current largest table size
  - Query: `SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) FROM pg_tables ORDER BY pg_total_relation_size DESC LIMIT 5;`

## System ID Documentation

- [ ] Record current system ID:
  ```bash
  sudo -u postgres pg_controldata /var/lib/postgresql/15/main | grep "Database system identifier"
  ```
  - Current System ID: `_____` (note this before restore)

## etcd Verification

- [ ] etcd is running: `systemctl status etcd`
- [ ] etcd cluster healthy: `sudo etcdctl cluster-health`
  - All members listed
  - All members healthy
  - Leader elected

- [ ] Can read etcd: `sudo etcdctl ls /service/patroni/`
  - Shows cluster data
  - No errors

## Log Files Ready

- [ ] Clear old log files (optional): `truncate -s 0 /var/log/postgresql/postgresql*.log`
- [ ] Note start time: `date` = `_______________`
- [ ] Log file locations documented:
  - pgBackRest: `/var/log/pgbackrest/`
  - PostgreSQL: `/var/log/postgresql/`
  - Patroni: `journalctl -u patroni`

## Automation/Scripts Ready

- [ ] Review restore script (if using): `[../scripts/restore_cluster.sh](../scripts/restore_cluster.sh)`
- [ ] Test script syntax: `bash -n /path/to/script.sh`
- [ ] Have rollback plan if automation fails

## Communication & Documentation

- [ ] Notify stakeholders of maintenance window
- [ ] Document expected downtime: ~30 minutes
- [ ] Backup of procedures is available
- [ ] Have contact info for escalation
- [ ] Have reference materials printed/accessible

## Final Readiness Check

- [ ] All checks above marked as complete: ✓
- [ ] No failures found
- [ ] All nodes accessible
- [ ] Backups verified
- [ ] Disk space sufficient
- [ ] Ready to proceed to restore procedures
- [ ] Time: `_____` (when you are ready)

---

## Issues Found?

If ANY item above fails:

1. **STOP - Do not proceed**
2. Check [../failure-analysis/](../failure-analysis/) for similar failures
3. Fix the issue
4. Re-run this checklist
5. Only proceed when ALL items pass

---

## Sign-Off

- Completed by: `___________________`
- Date: `___________________`
- Time: `___________________`
- Notes: `___________________________________________`

**I confirm all items above have been verified and no issues were found.**

Signature: `___________________`

---

**Next Step:** Begin [../procedures/01_CHECK_BACKUPS.md](../procedures/01_CHECK_BACKUPS.md)
