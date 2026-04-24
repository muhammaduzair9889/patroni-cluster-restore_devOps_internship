# Step 4: Run pgBackRest Restore

**Purpose:** Copy backup data from repository to database server.

**Estimated Time:** 5-10 minutes (depends on size)

**Difficulty:** Medium

## Overview

This is the core restore step where pgBackRest:
1. Reads backup from repository
2. Decompresses files
3. Copies to data directory
4. Copies WAL files for recovery
5. Verifies everything is correct

## Prerequisites

- Old data directory cleaned (Step 3 complete)
- Fresh empty directory created
- Backup verified (Step 1 complete)
- Backup repository accessible
- At least 100GB free disk space

## Procedure

### 4.1: Execute Restore Command on PRIMARY Only

```bash
# On PRIMARY node only (NOT on replicas)
ssh primary

# Run restore with delta flag (faster, safer)
sudo -u postgres pgbackrest restore --stanza=demo --delta

# Expected output:
# INFO: restore command complete successfully (retention not met)
# (The message is normal and not an error)
```

**Important Options:**

| Option | Meaning |
|--------|---------|
| `--stanza=demo` | Backup set to restore (must match config) |
| `--delta` | Delta restore (faster) - only copy changed files |
| `--verbose` | Show detailed progress (optional) |

### 4.2: Delta vs Full Restore

**--delta flag (Recommended):**
```bash
sudo -u postgres pgbackrest restore --stanza=demo --delta
```
- Compares existing files with backup
- Only copies files that differ
- Much faster (5 minutes vs 15 minutes)
- Safer (doesn't delete existing files)
- **Recommended for most cases**

**Full restore (Alternative):**
```bash
# Only use if --delta fails
sudo -u postgres pgbackrest restore --stanza=demo
```
- Removes all files, restores from backup
- Slower but more thorough
- Use if delta restore has issues

### 4.3: Monitor Restore Progress

The restore runs in foreground and shows progress. You can also monitor in another terminal:

```bash
# In another SSH session on primary
tail -f /var/log/pgbackrest/demo-restore.log
```

**Expected log output:**
```
INFO: restore command start: --delta --process-max=4 --recovery-option=primary_conninfo='' --repo1-type=posix --stanza=demo
DEBUG: archive_status directory exists: /var/lib/postgresql/15/main/pg_wal/archive_status
INFO: restore start time 2026-04-14 16:45:00
INFO: restore database files
...
INFO: restore complete, took 4m 32s
```

### 4.4: What Happens During Restore

```
Time T:00 - Start
├─ Read backup metadata
├─ Determine files to restore
└─ Begin file copy

Time T:02 - Copy Backup Data
├─ Decompress backup files
├─ Write to /var/lib/postgresql/15/main/base/
├─ Write to /var/lib/postgresql/15/main/global/
└─ Copy configuration files

Time T:04 - Copy WAL Files
├─ Copy WAL archives from backup
├─ Write to /var/lib/postgresql/15/main/pg_wal/
└─ Enable point-in-time recovery

Time T:05 - Verify & Complete
├─ Verify file checksums
├─ Confirm all files restored
└─ Display completion message

Total time: 5 minutes
```

### 4.5: Wait for Restore to Complete

```bash
# Keep watching the log
tail -f /var/log/pgbackrest/demo-restore.log

# Look for "restore complete" message
# Once you see it, restore is done
```

## Verification Checklist

Complete this before proceeding to Step 5:

- [ ] Restore command completed successfully
- [ ] No errors in output
- [ ] Log shows "restore complete"
- [ ] Data directory is populated
- [ ] At least 50GB of files exist

## Verify Data Directory is Populated

```bash
# Check data directory contents
sudo du -sh /var/lib/postgresql/15/main/

# Expected: ~50GB (original database size)

# Check specific subdirectories
sudo ls -la /var/lib/postgresql/15/main/base/
sudo ls -la /var/lib/postgresql/15/main/pg_wal/

# Expected: Many files and subdirectories
```

## Common Issues & Fixes

### Issue 1: "FATAL: unable to access '/mnt/pgbackrest-repo': Permission denied"

```bash
# Fix: Change repository ownership
sudo chown -R postgres:postgres /mnt/pgbackrest-repo
sudo chmod -R 0700 /mnt/pgbackrest-repo

# Retry restore
sudo -u postgres pgbackrest restore --stanza=demo --delta
```

### Issue 2: "ERROR: restore cannot proceed without a clean directory"

```bash
# Data directory has old files
# Clean again (Step 3) and retry

sudo rm -rf /var/lib/postgresql/15/main/*
sudo -u postgres pgbackrest restore --stanza=demo --delta
```

### Issue 3: "ERROR: invalid stanza 'demo'"

```bash
# Check stanza in config (case-sensitive)
sudo cat /etc/pgbackrest/pgbackrest.conf | grep stanza

# Fix: Ensure [demo] is lowercase in config
sudo nano /etc/pgbackrest/pgbackrest.conf

# Retry restore
sudo -u postgres pgbackrest restore --stanza=demo --delta
```

### Issue 4: Restore takes too long (> 15 minutes)

```bash
# Check disk I/O performance
iostat -x 5

# Check network performance (if NFS repository)
iftop -i eth0

# Check for errors in log
sudo tail -f /var/log/pgbackrest/demo-restore.log

# Possible causes:
# - Slow disk (SSD vs HDD)
# - Network issues (if NFS)
# - Insufficient memory (increases swapping)
```

## Recovery if Restore Fails

**If restore fails partway:**

```bash
# Option 1: Retry the restore (usually works)
sudo -u postgres pgbackrest restore --stanza=demo --delta

# Option 2: Full restore (if delta fails)
sudo -u postgres pgbackrest restore --stanza=demo

# Option 3: Clean and restore again
sudo rm -rf /var/lib/postgresql/15/main/*
sudo -u postgres pgbackrest restore --stanza=demo --delta
```

## Disk Space Monitoring

```bash
# Monitor disk usage during restore
while true; do
  clear
  df -h /var/lib/postgresql
  du -sh /var/lib/postgresql/15/main
  sleep 10
done
```

## Summary

This step restores all database files from backup. The restore includes data files, configuration, WAL files for recovery, and everything needed for the next step.

**Next:** Proceed to [05_VERIFY_FILES.md](05_VERIFY_FILES.md) once restore completes successfully.

---

**Troubleshooting:** See [../failure-analysis/FAILURE_MATRIX.md](../failure-analysis/FAILURE_MATRIX.md)
