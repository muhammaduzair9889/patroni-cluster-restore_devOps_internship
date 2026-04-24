# Common Failures Matrix - Quick Reference

Use this table to quickly identify failures and find solutions.

| Error Message | Symptom | File | Root Cause | Quick Fix | Time |
|---------------|---------|------|-----------|-----------|------|
| **Permission denied** | Restore fails immediately | [FAILURE_01](FAILURE_01_PERMISSIONS.md) | Repository not owned by postgres | `chown -R postgres:postgres /mnt/pgbackrest-repo` | 30 sec |
| **Stanza not found** | pgbackrest info returns error | [FAILURE_02](FAILURE_02_STANZA.md) | Config has [Demo], command uses demo | Change config to lowercase [demo] | 1 min |
| **System ID mismatch** | Patroni won't start | [FAILURE_03](FAILURE_03_SYSTEM_ID.md) | Stale etcd metadata | `etcdctl del /service/demo --prefix` | 2 min |
| **Cannot connect to etcd** | Patroni startup fails | See logs | etcd not running or network issue | `systemctl start etcd` or check network | 2 min |
| **Port 5432 in use** | PostgreSQL won't start | See [procedures/](../procedures/) | Another PostgreSQL or service using port | `killall -9 postgres` or change port | 1 min |
| **Data directory not empty** | pgBackRest restore fails | [procedures/](../procedures/) | Old data still present | Clean data directory again | 2 min |
| **Shared memory in use** | PostgreSQL startup fails | [procedures/07](../procedures/07_START_POSTGRESQL.md) | Previous PostgreSQL didn't clean up | `ipcrm -a` | 1 min |
| **WAL recovery stuck** | PostgreSQL hangs during recovery | See logs | I/O bottleneck or WAL corruption | Wait or check disk space | 5-30 min |
| **Database size mismatch** | Restore incomplete | [procedures/05](../procedures/05_VERIFY_FILES.md) | Restore failed partially | Re-run restore | 10 min |
| **PID file exists** | PostgreSQL won't start (stale) | [procedures/07](../procedures/07_START_POSTGRESQL.md) | Previous crash didn't clean up | `rm /var/run/postgresql/*.pid` | 30 sec |

---

## Error Message Index

### Permission/Access Errors

```
ERROR: unable to access '...': Permission denied
    └─ Check file ownership: ls -la /path/
    └─ Fix: chown postgres:postgres

ERROR: could not open file '...': Permission denied
    └─ Check file permissions: ls -la /path/file
    └─ Fix: chmod 0600 or 0700
```

### Configuration Errors

```
ERROR: stanza '...' not found
    └─ Check stanza name (case-sensitive)
    └─ Fix: Match case in config and commands

ERROR: configuration error: ...
    └─ Check /etc/pgbackrest/pgbackrest.conf syntax
    └─ Fix: Correct configuration file
```

### Database/Cluster Errors

```
FATAL: cluster identifier system identifier mismatch
    └─ Old etcd metadata vs new PostgreSQL
    └─ Fix: etcdctl del /service/demo --prefix

FATAL: pre-existing shared memory block is still in use
    └─ Old PostgreSQL process still holding memory
    └─ Fix: ipcrm -a
```

### Service/Process Errors

```
ERROR: connection refused
    └─ Service not running or wrong port
    └─ Fix: Check systemctl status, fix port

ERROR: no such file or directory
    └─ File doesn't exist at expected path
    └─ Fix: Check path, verify restoration
```

---

## By Step

### Step 1 Errors (Check Backups)
- Stanza not found → [FAILURE_02](FAILURE_02_STANZA.md)
- Permission denied → [FAILURE_01](FAILURE_01_PERMISSIONS.md)
- No backups found → Backups never created, create first backup

### Step 2 Errors (Stop Patroni)
- Cannot connect to nodes → Check SSH access, network
- Patroni not installed → Check installation
- etcd issues → Check etcd status, try restart

### Step 3 Errors (Clean Data Dir)
- Cannot access directory → Check permissions
- Cannot write to directory → Check disk space
- Directory in use → PostgreSQL still running, kill it

### Step 4 Errors (Run Restore)
- Permission denied → [FAILURE_01](FAILURE_01_PERMISSIONS.md)
- Stanza not found → [FAILURE_02](FAILURE_02_STANZA.md)
- Cannot proceed without clean directory → Clean directory in Step 3

### Step 5 Errors (Verify Files)
- Directory size is 0 → Restore failed, check Step 4 logs
- pg_control missing → Restore incomplete

### Step 6 Errors (Fix Permissions)
- Cannot change ownership → Need sudo access
- postgres user doesn't exist → Create user

### Step 7 Errors (Start PostgreSQL)
- Shared memory in use → `ipcrm -a`
- Port in use → `killall -9 postgres`
- Cannot read pg_control → Check permissions (Step 6)

### Step 8 Errors (Start Patroni)
- System ID mismatch → [FAILURE_03](FAILURE_03_SYSTEM_ID.md)
- Cannot connect to etcd → Check etcd status
- PostgreSQL won't start → Check error from Step 7

### Step 9 Errors (Verify Cluster)
- No leader elected → Check etcd, logs
- Replication not working → Check network, logs
- System IDs don't match → [FAILURE_03](FAILURE_03_SYSTEM_ID.md)

---

## Troubleshooting Decision Tree

```
Restore fails?
├─ Before pgBackRest starts? → Check permissions, stanza, etcd
├─ During pgBackRest? → Check disk space, network, logs
├─ After restore, during validation? → Check files, permissions
└─ After restore, during PostgreSQL start? → Check shared memory, port
    └─ After PostgreSQL starts? → Check WAL recovery logs
        └─ After Patroni starts? → Check system ID, etcd
            └─ Cluster up but replicas not synced? → Check network, WAL files
```

---

## Log File Locations

Monitor these files to diagnose failures:

```
pgBackRest logs:
  /var/log/pgbackrest/demo-restore.log

PostgreSQL logs:
  /var/log/postgresql/postgresql-15-main.log
  /tmp/postgres.log (during manual start)

Patroni logs:
  sudo journalctl -u patroni -f

etcd logs:
  sudo journalctl -u etcd -f

System logs:
  /var/log/syslog
  sudo dmesg
```

---

## Quick Help

**Stuck and don't know what to do?**

1. Check error message in this matrix
2. Follow the quick fix column
3. If not fixed, read detailed failure file
4. Still stuck? Check [../procedures/](../procedures/) for step details
5. Review [../LESSONS_LEARNED.md](../LESSONS_LEARNED.md) for insights

---

**Need detailed analysis?** See individual failure files:
- [FAILURE_01_PERMISSIONS.md](FAILURE_01_PERMISSIONS.md)
- [FAILURE_02_STANZA.md](FAILURE_02_STANZA.md)
- [FAILURE_03_SYSTEM_ID.md](FAILURE_03_SYSTEM_ID.md)
