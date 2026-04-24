# DURING-RESTORE CHECKLIST

**Use this checklist DURING restore procedure**

Follow along with [../procedures/](../procedures/) and check off items as you go.

## Step 1: Check Backups (5 minutes)

**Reference:** [../procedures/01_CHECK_BACKUPS.md](../procedures/01_CHECK_BACKUPS.md)

- [ ] List available backups: `pgbackrest info`
- [ ] Verify at least one backup with status "ok"
- [ ] Note backup date and size: `_____ GB`
- [ ] Note stanza name (should be `demo`): `_____`

**Status:** Started at `_____` Completed at `_____`

**Result:** ☐ OK ☐ PROBLEM (describe: `_____________________`)

---

## Step 2: Stop Patroni (5 minutes)

**Reference:** [../procedures/02_STOP_PATRONI.md](../procedures/02_STOP_PATRONI.md)

- [ ] Stop Patroni on PRIMARY: `sudo systemctl stop patroni`
- [ ] Stop Patroni on REPLICA-1: `ssh replica-1 "sudo systemctl stop patroni"`
- [ ] Stop Patroni on REPLICA-2: `ssh replica-2 "sudo systemctl stop patroni"`
- [ ] Verify all stopped: `patronictl list` should show error
- [ ] Verify etcd still running: `sudo systemctl status etcd`

**Status:** Started at `_____` Completed at `_____`

**Result:** ☐ OK ☐ PROBLEM (describe: `_____________________`)

---

## Step 3: Clean Data Directory (10 minutes)

**Reference:** [../procedures/03_CLEAN_DATA_DIR.md](../procedures/03_CLEAN_DATA_DIR.md)

- [ ] Backup old data dir: `sudo mv /var/lib/postgresql/15/main /var/lib/postgresql/15/main.backup`
- [ ] Create empty dir: `sudo mkdir -p /var/lib/postgresql/15/main`
- [ ] Fix ownership: `sudo chown postgres:postgres /var/lib/postgresql/15/main`
- [ ] Fix permissions: `sudo chmod 0700 /var/lib/postgresql/15/main`
- [ ] Verify disk space: `df -h /var/lib/postgresql` shows > 100GB free
- [ ] Verify empty: `ls -la /var/lib/postgresql/15/main/` shows only 3 entries (., .., lost+found)

**Status:** Started at `_____` Completed at `_____`

**Result:** ☐ OK ☐ PROBLEM (describe: `_____________________`)

---

## Step 4: Run Restore (15-30 minutes)

**Reference:** [../procedures/04_RUN_RESTORE.md](../procedures/04_RUN_RESTORE.md)

- [ ] Run restore command:
  ```bash
  sudo -u postgres pgbackrest restore --stanza=demo --delta
  ```

- [ ] Monitor progress (in another terminal):
  ```bash
  tail -f /var/log/pgbackrest/demo-restore.log
  ```

- [ ] Watch for "restore completed successfully" message
- [ ] Check restore log for errors: `grep -i error /var/log/pgbackrest/demo-restore.log`

**Restore started at:** `_____`

**Restore completed at:** `_____`

**Total restore time:** `_____` minutes (expected: 15-30 min)

**Database size restored:** Verify with: `du -sh /var/lib/postgresql/15/main/` = `_____ GB`

**Result:** ☐ OK ☐ PROBLEM (describe: `_____________________`)

---

## Step 5: Verify Files (5 minutes)

**Reference:** [../procedures/05_VERIFY_FILES.md](../procedures/05_VERIFY_FILES.md)

- [ ] Data directory has files: `ls -la /var/lib/postgresql/15/main/ | wc -l` should be > 100
- [ ] pg_control exists: `ls -la /var/lib/postgresql/15/main/pg_control` exists
- [ ] Size looks correct: `du -sh /var/lib/postgresql/15/main/` shows ~50GB (or your size)
- [ ] Base subdirectory exists: `ls -la /var/lib/postgresql/15/main/base/`
- [ ] Global subdirectory exists: `ls -la /var/lib/postgresql/15/main/global/`
- [ ] WAL files present: `ls /var/lib/postgresql/15/main/pg_wal/ | head -5` shows files

**Result:** ☐ OK ☐ PROBLEM (describe: `_____________________`)

---

## Step 6: Fix Permissions (5 minutes)

**Reference:** [../procedures/06_FIX_PERMISSIONS.md](../procedures/06_FIX_PERMISSIONS.md)

- [ ] Fix directory ownership: `sudo chown -R postgres:postgres /var/lib/postgresql/15/main`
- [ ] Fix directory permissions: `sudo find /var/lib/postgresql/15/main -type d -exec chmod 0700 {} \;`
- [ ] Fix file permissions: `sudo find /var/lib/postgresql/15/main -type f -exec chmod 0600 {} \;`
- [ ] Verify ownership: `ls -la /var/lib/postgresql/15/main/ | grep postgres`
- [ ] Verify permissions: `ls -la /var/lib/postgresql/15/main/pg_control` shows `-rw-------`

**Result:** ☐ OK ☐ PROBLEM (describe: `_____________________`)

---

## Step 7: Start PostgreSQL (10-20 minutes)

**Reference:** [../procedures/07_START_POSTGRESQL.md](../procedures/07_START_POSTGRESQL.md)

- [ ] Clear shared memory (if needed): `ipcrm -a`
- [ ] Start PostgreSQL (do NOT start as service):
  ```bash
  sudo -u postgres /usr/lib/postgresql/15/bin/postgres -D /var/lib/postgresql/15/main -F &
  ```

- [ ] Wait for "database system is ready" message in console output
- [ ] Watch for WAL recovery messages
- [ ] Note recovery time: Started at `_____` Completed at `_____`

**Expected messages:**
- ✓ "redo done at ..."
- ✓ "database system is ready to accept connections"

- [ ] Verify database is responsive:
  ```bash
  psql -U postgres -c "SELECT 1;"
  ```
  Should return `?column?` = 1

- [ ] Background PostgreSQL process (press Ctrl+C if in foreground)
- [ ] Start PostgreSQL as service:
  ```bash
  sudo systemctl start postgresql@15-main
  ```

**Status:** Started at `_____` WAL Recovery at `_____` Completed at `_____`

**WAL recovery time:** `_____` minutes

**Result:** ☐ OK ☐ PROBLEM (describe: `_____________________`)

---

## Step 8: Start Patroni (5 minutes)

**Reference:** [../procedures/08_START_PATRONI.md](../procedures/08_START_PATRONI.md)

- [ ] Start Patroni on PRIMARY: `sudo systemctl start patroni`
- [ ] Wait for election: `sleep 30`
- [ ] Check status: `patronictl list`
- [ ] Verify PRIMARY elected: Shows one "Leader" node
- [ ] Start Patroni on REPLICA-1: `ssh replica-1 "sudo systemctl start patroni"`
- [ ] Check status: `patronictl list`
- [ ] Wait for replicas to sync: `sleep 30`
- [ ] Start Patroni on REPLICA-2: `ssh replica-2 "sudo systemctl start patroni"`
- [ ] Final status check: `patronictl list`

**Expected:**
```
| Member    | Role    | State   | Lag |
|-----------|---------|---------|-----|
| primary   | Leader  | running | 0B  |
| replica-1 | Replica | running | 0B  |
| replica-2 | Replica | running | 0B  |
```

**Status:** Patroni started at `_____`

**Result:** ☐ OK ☐ PROBLEM (describe: `_____________________`)

---

## Step 9: Verify Cluster (10 minutes)

**Reference:** [../procedures/09_VERIFY_CLUSTER.md](../procedures/09_VERIFY_CLUSTER.md)

- [ ] Cluster list shows all 3 nodes: `patronictl list`
- [ ] Replication verified: `psql -c "SELECT COUNT(*) FROM pg_stat_replication;"` returns 2
- [ ] All replicas streaming: `psql -c "SELECT state FROM pg_stat_replication;"` all show "streaming"
- [ ] Lag minimal: `psql -c "SELECT replay_lag FROM pg_stat_replication;"` all < 1 second
- [ ] No errors in logs: Check `/var/log/postgresql/postgresql-15-main.log`
- [ ] Database accepts writes: `psql -c "INSERT INTO test VALUES (1);"` succeeds
- [ ] Data replicated: Check same data on replicas

**Status:** Verification completed at `_____`

**Result:** ☐ OK ☐ PROBLEM (describe: `_____________________`)

---

## Summary

- **Total restore time (Steps 1-9):** `_____` minutes (expected: 45-90 min)
- **Longest step:** `_____` (expected: Step 7 WAL recovery)
- **Issues encountered:** ☐ None ☐ Yes (describe: `_____________________`)

**Overall result:**
- ☐ SUCCESSFUL RESTORE - All steps completed
- ☐ PARTIAL SUCCESS - Some issues found (see above)
- ☐ FAILED - Restore unsuccessful (see above)

---

## Next Steps

If SUCCESSFUL:
1. Run [POST_RESTORE_CHECKLIST.md](POST_RESTORE_CHECKLIST.md)
2. Document timings for future reference
3. Notify stakeholders
4. Review [../LESSONS_LEARNED.md](../LESSONS_LEARNED.md)

If PARTIAL SUCCESS:
1. Review issues found
2. Check [../failure-analysis/](../failure-analysis/) for solutions
3. Execute fixes
4. Re-run affected steps
5. Proceed when all pass

If FAILED:
1. Stop immediately
2. Review error logs carefully
3. Check [../failure-analysis/](../failure-analysis/)
4. Get help from PostgreSQL experts
5. Plan rollback if needed

---

**Completed by:** `___________________`

**Date:** `___________________`

**Signature:** `___________________`
