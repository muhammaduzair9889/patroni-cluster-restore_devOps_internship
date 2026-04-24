# Quick Start - Essential Commands & Shortcuts

This page contains the most commonly-used commands and quick fixes for the restoration process.

## 🚀 Standard Restore Commands

### Check Available Backups
```bash
pgbackrest info
```
**Output:** List of all available backups with timestamps

### Step-by-Step Restore (Manual)

```bash
# 1. Stop Patroni on all nodes
sudo systemctl stop patroni

# 2. Clean data directory
sudo mv /var/lib/postgresql/15/main /var/lib/postgresql/15/main.backup
sudo mkdir -p /var/lib/postgresql/15/main

# 3. Restore from backup (run once on primary node)
sudo -u postgres pgbackrest restore --stanza=demo --delta

# 4. Fix permissions
sudo chown -R postgres:postgres /var/lib/postgresql/15/main
sudo chmod 0700 /var/lib/postgresql/15/main

# 5. Start PostgreSQL manually
sudo -u postgres /usr/lib/postgresql/15/bin/pg_ctl start -D /var/lib/postgresql/15/main -l /tmp/postgres.log

# 6. Wait for recovery (watch log)
tail -f /tmp/postgres.log

# 7. Stop PostgreSQL
sudo -u postgres /usr/lib/postgresql/15/bin/pg_ctl stop -D /var/lib/postgresql/15/main

# 8. Start Patroni
sudo systemctl start patroni

# 9. Verify cluster health
patronictl list
```

### Automated Restore (Using Script)
```bash
bash scripts/restore_cluster.sh
```

## 🔍 Quick Health Checks

### View Cluster Status
```bash
patronictl list
```
**Expected Output:**
```
+-----------+----------+-----+---------+
| Member    | Host     | Role| Status  |
+-----------+----------+-----+---------+
| primary   | 10.0.1.1 | L   | running |
| replica-1 | 10.0.1.2 | F   | running |
| replica-2 | 10.0.1.3 | F   | running |
+-----------+----------+-----+---------+
```

### Check PostgreSQL Status
```bash
sudo systemctl status postgresql@15-main
```

### Check Patroni Status
```bash
sudo systemctl status patroni
```

### Check Replication Status
```bash
sudo -u postgres psql -c "SELECT slot_name, active, restart_lsn FROM pg_replication_slots;"
```

### Check Connected Replicas
```bash
sudo -u postgres psql -c "SELECT application_name, client_addr, write_lsn, sync_state FROM pg_stat_replication;"
```

### Monitor WAL Recovery
```bash
tail -f /var/log/postgresql/postgresql-15-main.log
```

## 🔧 Quick Fixes for Common Problems

### Problem: Permission Denied

**Error:**
```
ERROR: unable to access '/mnt/pgbackrest-repo': Permission denied
```

**Fix:**
```bash
sudo chown -R postgres:postgres /mnt/pgbackrest-repo
sudo chmod -R 0700 /mnt/pgbackrest-repo
```

**Verify:**
```bash
ls -ld /mnt/pgbackrest-repo
```
**Expected:** `drwx------ postgres postgres`

---

### Problem: Stanza Mismatch

**Error:**
```
ERROR: stanza 'demo' not found in '/etc/pgbackrest/pgbackrest.conf'
```

**Fix:**
1. Check config file:
```bash
sudo cat /etc/pgbackrest/pgbackrest.conf | grep -i stanza
```

2. Ensure stanza name matches exactly (case-sensitive):
```bash
# In config file - must be lowercase
[demo]

# In commands - must be lowercase
pgbackrest restore --stanza=demo
```

---

### Problem: System Identifier Mismatch

**Error:**
```
FATAL: cluster identifier system identifier mismatch
```

**Fix:**
```bash
# On primary node only
sudo etcdctl del /service/patroni/cluster_name --prefix

# Wait 5 seconds, then start Patroni
sudo systemctl start patroni

# Verify cluster re-initialized
patronictl list
```

---

### Problem: Data Directory Not Empty

**Error:**
```
ERROR: restore cannot proceed without a clean directory
```

**Fix:**
```bash
sudo mv /var/lib/postgresql/15/main /var/lib/postgresql/15/main.bak
sudo mkdir /var/lib/postgresql/15/main
sudo chown postgres:postgres /var/lib/postgresql/15/main
sudo chmod 0700 /var/lib/postgresql/15/main
```

---

### Problem: PostgreSQL Won't Start

**Error:**
```
FATAL: pre-existing shared memory block is still in use
```

**Fix:**
```bash
sudo sysctl -w kernel.shmmax=1073741824
sudo sysctl -w kernel.shmall=262144

# Or use ipcrm to remove shared memory
sudo ipcrm -a
```

---

### Problem: Patroni Fails to Start

**Check the log:**
```bash
sudo journalctl -u patroni -f
```

**Common causes:**
- etcd not running: `sudo systemctl start etcd`
- PostgreSQL won't stop: `sudo systemctl kill postgresql`
- Old PID file: `sudo rm /var/run/postgresql/15-main.pid`

---

## 📊 Quick Monitoring Commands

### Real-time Replication Status
```bash
# Watch lag bytes and LSN positions
watch -n 1 'psql -c "SELECT application_name, client_addr, write_lsn FROM pg_stat_replication;"'
```

### Check Backup Progress
```bash
# Monitor restore progress (on restore machine)
sudo tail -f /var/log/pgbackrest/demo-restore.log
```

### Monitor Disk Usage
```bash
# Watch data directory size growth during restore
watch -n 5 'du -sh /var/lib/postgresql/15/main'
```

## 🎯 Critical Verification Steps

### After Restore Completes:

1. **Check all 3 nodes online:**
   ```bash
   patronictl list
   ```

2. **Check primary elected:**
   ```bash
   patronictl list | grep L
   ```

3. **Check replicas connected:**
   ```bash
   sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_replication;"
   ```
   **Expected:** `2` (two replicas connected)

4. **Check replication lag:**
   ```bash
   sudo -u postgres psql -c "SELECT max(abs(extract(epoch from clock_timestamp()) - pg_xact_xmin_age(xmin))) FROM pg_stat_replication;"
   ```
   **Expected:** < 1 second

5. **Check data integrity:**
   ```bash
   # Run test query to verify data
   sudo -u postgres psql -c "SELECT count(*) FROM pg_class WHERE relname='YOUR_TABLE_NAME';"
   ```

## ⚡ One-Liners for Common Tasks

### Kill stuck PostgreSQL process
```bash
sudo killall -9 postgres
```

### Remove all Patroni lock files
```bash
sudo rm -f /var/run/postgresql/*.lock
```

### Clear etcd cluster state
```bash
sudo etcdctl del /service/demo --prefix
```

### Reset PostgreSQL WAL position
```bash
sudo -u postgres pg_controldata /var/lib/postgresql/15/main | head -10
```

### View Patroni configuration
```bash
sudo patronictl show-config
```

### Edit cluster configuration
```bash
sudo patronictl edit-config
```

## 📋 Troubleshooting Decision Tree

```
Cluster not responding?
├─ All nodes down?
│  └─ Run: systemctl status patroni (all nodes)
│  └─ Fix: systemctl start patroni
│
├─ Some nodes down?
│  └─ Run: patronictl list
│  └─ Check: journalctl -u patroni -n 50
│  └─ Fix: systemctl restart patroni
│
└─ No primary elected?
   └─ Run: sudo etcdctl ls /service/demo
   └─ Check: etcd health
   └─ Fix: etcdctl del /service/demo --prefix && systemctl restart patroni

PostgreSQL won't start?
├─ Permission error?
│  └─ Fix: chown -R postgres:postgres /var/lib/postgresql/15/main
│
├─ Port 5432 in use?
│  └─ Run: lsof -i :5432
│  └─ Fix: killall -9 postgres
│
└─ Shared memory error?
   └─ Fix: ipcrm -a && sysctl -w kernel.shmmax=1073741824

Restore stuck?
├─ Check disk space?
│  └─ Run: df -h
│  └─ Fix: Free up space or use different partition
│
├─ Check network?
│  └─ Run: ping backup-server
│  └─ Fix: Check network connectivity
│
└─ Check process?
   └─ Run: ps aux | grep pgbackrest
   └─ Fix: Check pgBackRest log for errors
```

## 📚 Link to Detailed Procedures

For more detailed steps, see the [procedures/](../procedures/) directory:
- [procedures/01_CHECK_BACKUPS.md](../procedures/01_CHECK_BACKUPS.md)
- [procedures/02_STOP_PATRONI.md](../procedures/02_STOP_PATRONI.md)
- ... (all 9 steps)

---

**Need more help?** Check the [failure-analysis/](../failure-analysis/) directory for real-world examples.
