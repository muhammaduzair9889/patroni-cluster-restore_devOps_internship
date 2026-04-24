# FAILURE_DECISION_TREE - Interactive Troubleshooting Guide

Use this guide to identify and fix failures during restore.

## Quick Start: Where Is Your Problem?

```
I'm trying to:
┌────────────────────────────────────────────────────────────────┐
│                                                                │
├─ ❶ Check if backups exist                                     │
│   └─> Go to: Backup Verification (below)                      │
│                                                                │
├─ ❷ Stop Patroni on all nodes                                  │
│   └─> Go to: Patroni Startup/Stopping (below)                │
│                                                                │
├─ ❸ Run pgBackRest restore                                     │
│   └─> Go to: Restore Execution (below)                        │
│                                                                │
├─ ❹ Verify restored files                                      │
│   └─> Go to: File Verification (below)                        │
│                                                                │
├─ ❺ Start PostgreSQL                                           │
│   └─> Go to: PostgreSQL Startup (below)                       │
│                                                                │
├─ ❻ Start Patroni on all nodes                                 │
│   └─> Go to: Patroni Startup/Stopping (below)                │
│                                                                │
├─ ❼ Verify cluster is healthy                                  │
│   └─> Go to: Cluster Verification (below)                     │
│                                                                │
└─ ❽ Troubleshoot an error (error message)                      │
    └─> Go to: Error Messages (below)                           │
└─ ❾ Troubleshoot by symptom                                    │
    └─> Go to: Symptom Guide (below)                            │
```

---

## Error Messages - Quick Lookup

```
ERROR MESSAGE                      LOCATION                  LIKELY CAUSE
═════════════════════════════════════════════════════════════════════════════
Permission denied                  Error Messages → Access   Repository not owned
                                  Errors                     by postgres

stanza '...' not found            Error Messages → Config   Stanza name case
                                  Errors                     mismatch

System ID mismatch                Error Messages → Cluster  Stale etcd metadata
                                  Errors

No backups found                  Backup Verification       No backups created

Cannot connect to etcd            Patroni Startup           etcd not running or
                                                             network issue

Data directory not empty          Restore Execution         Old data still present

Cannot write to directory         File Operations           Permissions issue

PostgreSQL won't start            PostgreSQL Startup        Port in use or bad
                                                             pg_control

No leader elected                 Cluster Verification      etcd issue or timing
```

---

## Detailed Decision Trees

### BACKUP VERIFICATION
```
1. Run: pgbackrest info
   │
   ├─ ERROR: "not a valid pgBackRest repository"
   │  ├─ Problem: Wrong path or repository corrupt
   │  ├─ Fix: Verify /etc/pgbackrest/pgbackrest.conf points to correct repo
   │  ├─ Check: ls -la /mnt/pgbackrest-repo/
   │  └─ Escalate: Restore from different backup repository
   │
   ├─ ERROR: "stanza '...' not found"
   │  ├─ Problem: Config has [Demo], command uses demo (case matters!)
   │  ├─ Fix: Edit /etc/pgbackrest/pgbackrest.conf, change [Demo] to [demo]
   │  └─ Verify: pgbackrest info (should work now)
   │
   ├─ ERROR: "permission denied"
   │  ├─ Problem: postgres user can't read repository
   │  ├─ Check: ls -ld /mnt/pgbackrest-repo/ (should be postgres:postgres)
   │  ├─ Fix: sudo chown -R postgres:postgres /mnt/pgbackrest-repo/
   │  └─ Retry: pgbackrest info
   │
   └─ SUCCESS: Shows "status=ok" for at least one backup
      └─ CONTINUE to Step 1: Check Backups procedure
```

### PATRONI STARTUP/STOPPING
```
2. Stop Patroni: systemctl stop patroni
   │
   ├─ ERROR: "unit not found"
   │  ├─ Problem: Patroni not installed
   │  ├─ Fix: apt-get install patroni (or equivalent)
   │  └─ Retry: systemctl stop patroni
   │
   ├─ ERROR: "Failed to stop patroni.service"
   │  ├─ Problem: Patroni process stuck
   │  ├─ Check: systemctl status patroni (what's the issue?)
   │  ├─ Force: sudo killall -9 patroni
   │  └─ Verify: systemctl status patroni (should be inactive)
   │
   ├─ SLOW: Takes > 30 seconds
   │  ├─ Problem: Database is shutting down transactions
   │  ├─ Wait: Let it finish
   │  ├─ Force if needed: systemctl stop patroni --force
   │  └─ Check PostgreSQL: systemctl status postgresql@15-main
   │
   └─ SUCCESS: patroni is stopped
      │
      3. Start Patroni: systemctl start patroni
         │
         ├─ ERROR: "System ID mismatch"
         │  ├─ Problem: etcd has old system ID, PostgreSQL has new
         │  ├─ Fix: sudo etcdctl del /service/demo --prefix
         │  ├─ Verify: patronictl list should show cluster
         │  └─ Check: All 3 nodes online
         │
         ├─ ERROR: "Cannot connect to etcd"
         │  ├─ Problem: etcd not running or network issue
         │  ├─ Check: systemctl status etcd (is it running?)
         │  ├─ Fix: sudo systemctl restart etcd
         │  ├─ Test: sudo etcdctl cluster-health
         │  └─ Verify: patronictl list
         │
         └─ SUCCESS: Patroni running
            └─ Check with: patronictl list
```

### RESTORE EXECUTION
```
4. Run: pgbackrest restore --stanza=demo --delta
   │
   ├─ ERROR: "permission denied"
   │  ├─ Problem: User can't write to data directory
   │  ├─ Check: ls -la /var/lib/postgresql/15/ | grep main
   │  ├─ Fix: sudo chown -R postgres:postgres /var/lib/postgresql/15/main
   │  ├─ Verify: ls -la /var/lib/postgresql/15/main/ (postgres:postgres)
   │  └─ Retry: pgbackrest restore --stanza=demo --delta
   │
   ├─ ERROR: "database directory is not empty"
   │  ├─ Problem: Old data still in directory
   │  ├─ Check: ls -la /var/lib/postgresql/15/main/ (should be empty)
   │  ├─ Fix: rm -rf /var/lib/postgresql/15/main/*
   │  ├─ Verify: ls -la /var/lib/postgresql/15/main/ (only dot dirs)
   │  └─ Retry: pgbackrest restore --stanza=demo --delta
   │
   ├─ ERROR: "not enough disk space"
   │  ├─ Problem: Not enough free space
   │  ├─ Check: df -h /var/lib/postgresql (free space?)
   │  ├─ Fix: Clean up old data, vacuum other partitions
   │  ├─ Need: At least database_size + 20% extra
   │  └─ Retry: pgbackrest restore --stanza=demo --delta
   │
   ├─ SLOW: Restore taking very long
   │  ├─ Monitor: tail -f /var/log/pgbackrest/demo-restore.log
   │  ├─ Check: du -sh /var/lib/postgresql/15/main/ (growing?)
   │  ├─ Network: ping -c 10 repository (latency?)
   │  ├─ IO: iostat 1 (disk I/O saturated?)
   │  └─ Wait: Can take 15-30+ min for large databases
   │
   └─ SUCCESS: "restore completed successfully"
      └─ Verify file sizes and data directory contents
         (See: FILE VERIFICATION below)
```

### FILE VERIFICATION
```
5. Verify: ls -la /var/lib/postgresql/15/main/
   │
   ├─ PROBLEM: Directory is empty (0 files)
   │  ├─ Cause: Restore failed silently
   │  ├─ Check: tail -50 /var/log/pgbackrest/demo-restore.log
   │  ├─ Look for: "ERROR" or "FATAL" messages
   │  ├─ Fix: Address the error found in logs
   │  └─ Retry: pgbackrest restore --stanza=demo --delta
   │
   ├─ PROBLEM: Size is 0 or very small (< 10 MB)
   │  ├─ Cause: Restore didn't copy data
   │  ├─ Check: "restore completed successfully" in logs?
   │  ├─ No?: Restore failed, see error above
   │  ├─ Yes?: Try restore again or check backup
   │  └─ Last resort: Restore from different backup
   │
   ├─ PROBLEM: Missing pg_control file
   │  ├─ Cause: Restore incomplete
   │  ├─ Check: ls -la /var/lib/postgresql/15/main/pg_control
   │  ├─ File exists but unreadable: Fix permissions (Step 6)
   │  ├─ File missing: Restore incomplete
   │  ├─ Fix: Retry restore from fresh clean directory
   │  └─ Verify: pg_control is readable after restore
   │
   └─ SUCCESS: Restore looks complete
      ├─ Database size correct (du -sh shows ~50GB or your size)
      ├─ pg_control exists (ls -la shows file)
      ├─ base/ directory exists (ls base/)
      ├─ global/ directory exists (ls global/)
      └─ Continue to: PERMISSIONS FIXING below
```

### PERMISSIONS FIXING
```
6. Fix: chown -R postgres:postgres /var/lib/postgresql/15/main
   │
   ├─ ERROR: "operation not permitted"
   │  ├─ Cause: Not running as root/sudo
   │  ├─ Fix: Run with sudo
   │  └─ Retry: sudo chown -R postgres:postgres /var/lib/postgresql/15/main
   │
   └─ SUCCESS: Ownership changed
      │
      7. Fix: find /var/lib/postgresql/15/main -type d -exec chmod 0700 {} \;
         find /var/lib/postgresql/15/main -type f -exec chmod 0600 {} \;
         │
         ├─ ERROR: "operation not permitted"
         │  ├─ Cause: Not running as root/sudo
         │  ├─ Fix: Run with sudo
         │  └─ Retry: (repeat with sudo)
         │
         └─ SUCCESS: Permissions fixed
            └─ Verify: ls -la /var/lib/postgresql/15/main/pg_control
                      (should show -rw------- postgres:postgres)
               Continue to: POSTGRESQL STARTUP below
```

### POSTGRESQL STARTUP
```
7. Start: sudo -u postgres /usr/lib/postgresql/15/bin/postgres -D /var/lib/postgresql/15/main -F
   │
   ├─ ERROR: "address already in use"
   │  ├─ Cause: Port 5432 occupied
   │  ├─ Check: ss -tlnp | grep 5432 (what's using it?)
   │  ├─ Kill: sudo killall -9 postgres
   │  ├─ Wait: sleep 5
   │  └─ Retry: Start command again
   │
   ├─ ERROR: "could not create shared memory segment"
   │  ├─ Cause: Old PostgreSQL holding shared memory
   │  ├─ Check: ipcs -m (what segments exist?)
   │  ├─ Fix: ipcrm -m segment_id (for each segment)
   │  ├─ Alternative: sudo ipcrm -a (clear all - CAUTION!)
   │  └─ Retry: Start command again
   │
   ├─ ERROR: "PID file exists"
   │  ├─ Cause: Stale PID file from crash
   │  ├─ Fix: rm /var/run/postgresql/*.pid
   │  ├─ Verify: ls -la /var/run/postgresql/
   │  └─ Retry: Start command again
   │
   ├─ ERROR: "FATAL - pg_control damaged"
   │  ├─ Cause: pg_control file corrupt
   │  ├─ Check: file /var/lib/postgresql/15/main/pg_control
   │  ├─ Possible: Restore failed, data corrupt
   │  ├─ Fix: Restore again from different backup
   │  └─ Investigate: Why is restore creating corrupt data?
   │
   ├─ WARNING: "redo done at ... 10%" (or similar)
   │  ├─ Normal: WAL recovery in progress
   │  ├─ Expected: "redo done at X" followed by more messages
   │  ├─ Takes time: 10-20 minutes typical, depending on WAL size
   │  └─ Wait: Don't interrupt! Let it finish
   │
   └─ SUCCESS: "database system is ready to accept connections"
      │
      ├─ Background it: Press Ctrl+Z, then bg (if in foreground)
      ├─ Or just close: Ctrl+C (it will background)
      └─ Start as service: systemctl start postgresql@15-main
         Verify: systemctl status postgresql@15-main (should show active)
         Continue to: CLUSTER VERIFICATION below
```

### CLUSTER VERIFICATION
```
8. After all nodes running and replicas synced:
   │
   ├─ ERROR: patronictl list shows "unhealthy"
   │  ├─ Problem: Network or etcd issue
   │  ├─ Check: sudo etcdctl cluster-health
   │  ├─ Verify: All nodes can reach each other
   │  ├─ Test: ping replica-1, ping replica-2
   │  ├─ Fix: Check network routing, firewall
   │  └─ Retry: patronictl list
   │
   ├─ ERROR: "No leader elected"
   │  ├─ Cause: etcd not working or all nodes unhealthy
   │  ├─ Check: patronictl list (what's status?)
   │  ├─ Check: sudo etcdctl cluster-health
   │  ├─ Fix: Ensure all PostgreSQL processes running
   │  ├─ Restart etcd if needed: systemctl restart etcd
   │  ├─ Wait: Leader election takes ~10-30 seconds
   │  └─ Retry: patronictl list
   │
   ├─ WARNING: "Lag: 100MB" (replication lag)
   │  ├─ Normal: Temporary lag during heavy load
   │  ├─ Expected: Should catch up within seconds
   │  ├─ Monitor: psql -c "SELECT replay_lag FROM pg_stat_replication;"
   │  ├─ Problem if: Stays high (> 1 second)
   │  ├─ Check: Network latency, disk I/O
   │  └─ Wait: Can catch up on its own
   │
   └─ SUCCESS: All nodes online, replicas syncing
      ├─ Status: patronictl list shows Leader + 2 Replicas
      ├─ Lag: "0B" or < 100MB and decreasing
      ├─ Verify: psql -c "SELECT COUNT(*) FROM pg_stat_replication;" = 2
      └─ Continue to: POST-RESTORE CHECKS below
```

### SYMPTOM GUIDE (If you don't know the exact error)

**Symptom: Nothing happens, command hangs**
```
├─ Restore hanging?
│  ├─ Network issue: Check network connectivity
│  ├─ IO bottleneck: Check disk I/O (iostat)
│  ├─ Kill it: Ctrl+C, restart from Step 3
│  └─ Debug: tail -f /var/log/pgbackrest/demo-restore.log
│
└─ PostgreSQL startup hanging?
   ├─ WAL recovery: Normal, can take 10-20 min
   ├─ Check logs: tail -f /tmp/postgres.log
   ├─ Disk full: Check df -h
   └─ Wait or kill if stuck > 1 hour
```

**Symptom: Service won't start**
```
├─ systemctl says "failed"
│  ├─ Check: systemctl status postgresql@15-main
│  ├─ Review: journalctl -u postgresql@15-main -n 50
│  ├─ Check log file: tail -50 /var/log/postgresql/postgresql-15-main.log
│  └─ Fix: Address the specific error shown
│
└─ Service is masked?
   ├─ Fix: systemctl unmask postgresql@15-main
   └─ Then: systemctl start postgresql@15-main
```

**Symptom: Replication not working**
```
├─ psql -c "SELECT * FROM pg_stat_replication;" returns 0 rows
│  ├─ Check: PostgreSQL on replicas running?
│  ├─ Check: Network connectivity (ping replicas)
│  ├─ Check: Patroni configuration - replication settings
│  ├─ Check: pg_hba.conf allows replication connections
│  └─ Fix: Address the issue, restart replica PostgreSQL
│
└─ State shows "catchup" or "backup"
   ├─ Normal: Replica is catching up
   ├─ Check: replay_lag (should decrease over time)
   └─ Wait: Will become "streaming" when caught up
```

---

## Testing Your Fix

After applying a fix:

1. Verify fix was effective: Re-run the test command
2. Check logs: tail -50 relevant.log
3. Proceed to next step
4. If still fails: Document error, see detailed failure-analysis files

---

## Escalation Path

If you're stuck:

1. ✓ Check: Did you review all messages in failure-analysis/ directory?
2. ✓ Check: Did you verify the exact error message?
3. ✓ Check: Did you try the quick fix?
4. ✗ Still broken?
   ├─ Consult: [../failure-analysis/FAILURE_MATRIX.md](../failure-analysis/FAILURE_MATRIX.md)
   ├─ Read: Detailed failure files for your error
   ├─ Search: PostgreSQL documentation
   ├─ Contact: Your PostgreSQL expert
   ├─ Last resort: Restore from different backup or point-in-time

---

## Common Patterns

**Pattern 1: Permissions problems**
```
Usually manifests as: "permission denied"
Quick fix: sudo chown -R postgres:postgres /path/
Always verify: ls -la /path/ (should be postgres:postgres)
Prevention: Set correct permissions BEFORE restore
```

**Pattern 2: Configuration mistakes**
```
Usually manifests as: "not found", "invalid"
Quick fix: Check /etc/pgbackrest/pgbackrest.conf
Verify: Spelling, case sensitivity, syntax
Prevention: Test config with: pgbackrest info
```

**Pattern 3: Resource exhaustion**
```
Usually manifests as: "out of space", "no memory"
Quick fix: Clean up disk, kill other processes
Verify: df -h, free -h (before restore)
Prevention: Monitor resources during restore
```

**Pattern 4: Process conflicts**
```
Usually manifests as: "port in use", "already running"
Quick fix: killall -9 postgres, killall -9 patroni
Verify: No processes left (ps aux | grep postgres)
Prevention: Ensure clean state before restore
```

---

**REMEMBER:** If stuck, go step-by-step. Document the exact error. Check documentation for similar errors. When in doubt, reach out for help before things get worse!

**Reference:** [../README.md](../README.md) | [../failure-analysis/](../failure-analysis/) | [../procedures/](../procedures/)
