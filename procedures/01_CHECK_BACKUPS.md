# Step 1: Check Existing Backups

**Purpose:** Verify that backups exist and are usable for restoration.

**Estimated Time:** 2 minutes

**Difficulty:** Easy

## Overview

Before attempting any restore, you must verify:
1. Backup repository is accessible
2. Backups exist and are valid
3. Backup is recent enough (typically within last week)
4. Stanza is configured correctly in pgBackRest

## Prerequisites

- SSH access to primary node
- pgBackRest version 2.49+ installed
- Backup repository mounted/accessible
- `/etc/pgbackrest/pgbackrest.conf` configured correctly

## Procedure

### 1.1: List Available Backups

```bash
sudo -u postgres pgbackrest info
```

**Expected Output:**
```
stanza: demo
    status: ok
    
    db (current)
        wal archive min/max (15): 000000010000000000000001/000000010000000000009999
        
        full backup: 20260410-164501F
            timestamp start/stop: 2026-04-10 16:45:01 +0000 / 2026-04-10 17:15:30 +0000
            wal included: false
            database size: 50.1GB, backup size: 5.1GB
            repository size: 5.1GB, repository backup size: 5.1GB
            status: ok
            
        diff backup: 20260412-164510D
            timestamp start/stop: 2026-04-12 16:45:10 +0000 / 2026-04-12 16:50:25 +0000
            wal included: false
            parent backup: 20260410-164501F
            database size: 50.2GB, backup size: 3.0GB
            repository size: 3.0GB
            status: ok
            
        incr backup: 20260414-164520I
            timestamp start/stop: 2026-04-14 16:45:20 +0000 / 2026-04-14 16:47:15 +0000
            wal included: false
            parent backup: 20260412-164510D
            database size: 50.3GB, backup size: 1.2GB
            repository size: 1.2GB
            status: ok
```

### 1.2: Interpret the Output

**Key Information:**

| Field | Meaning |
|-------|---------|
| `stanza: demo` | Backup set name (must match pgbackrest.conf) |
| `status: ok` | Backup is valid and ready to restore |
| `full backup` | Starting point - contains all data |
| `diff backup` | Changes since full - faster incremental |
| `incr backup` | Changes since last backup - fastest |
| `timestamp` | When backup was created |
| `database size` | Production database size |
| `backup size` | Compressed backup size |
| `wal included` | Does backup include WAL? (Usually false) |

### 1.3: Determine Restore Point

**Choose the most recent backup:**
- If full backup is recent: Use full backup
- If differential is recent: Use full + differential
- If incremental is recent: Use full + differential + incremental

**Example Decision:**
```
Available Backups:
├─ Full: 2026-04-10 (4 days old)
├─ Diff: 2026-04-12 (2 days old) ← Good candidate
└─ Incr: 2026-04-14 (Today)      ← Best candidate

Decision: Restore to 2026-04-14 using full+diff+incr
Reason: Most recent, smallest footprint, fastest restore
```

### 1.4: Verify Backup is Not Corrupted

```bash
# This is automatic in pgbackrest info, but you can verify
sudo -u postgres pgbackrest info --stanza=demo --verbose
```

**Look for:**
- `status: ok` (not `error` or `expired`)
- No warnings or errors in output
- All parent backups available

### 1.5: Check Repository Accessibility

```bash
# Verify repository path
ls -la /mnt/pgbackrest-repo/demo/backup/

# Expected: Directory listing showing backup subdirectories
# Example output:
# total 12
# drwxr-x--- 2 postgres postgres 4096 Apr 10 16:45 20260410-164501F
# drwxr-x--- 2 postgres postgres 4096 Apr 12 16:45 20260412-164510D
# drwxr-x--- 2 postgres postgres 4096 Apr 14 16:45 20260414-164520I
```

### 1.6: Check Available Disk Space

```bash
# Check free space on /var/lib/postgresql partition
df -h /var/lib/postgresql

# Expected: At least 100GB free
# Example:
# Filesystem      Size  Used Avail Use% Mounted on
# /dev/sda2       500G  250G  250G  50% /var/lib/postgresql
```

### 1.7: Verify Stanza Configuration

```bash
# Check pgBackRest configuration
sudo cat /etc/pgbackrest/pgbackrest.conf | grep -A 5 "\[demo\]"

# Expected output (ensure stanza name is exact):
# [demo]
# pg1-path=/var/lib/postgresql/15/main
# pg1-port=5432
```

**Important:** Stanza name is **CASE-SENSITIVE**
- ✅ Correct: `[demo]` with lowercase
- ❌ Wrong: `[Demo]` with uppercase
- ❌ Command: `--stanza=demo` (lowercase)

## Common Issues & Fixes

### Issue 1: "ERROR: stanza 'demo' not found"

```bash
# Check what stanzas are configured
sudo cat /etc/pgbackrest/pgbackrest.conf | grep "\["

# Fix: Ensure config has lowercase [demo], not [Demo]
sudo nano /etc/pgbackrest/pgbackrest.conf
```

### Issue 2: "ERROR: unable to access '/mnt/pgbackrest-repo': Permission denied"

```bash
# Check permissions
ls -ld /mnt/pgbackrest-repo

# Fix: Change owner to postgres
sudo chown -R postgres:postgres /mnt/pgbackrest-repo
sudo chmod -R 0700 /mnt/pgbackrest-repo

# Verify
ls -ld /mnt/pgbackrest-repo
# Expected: drwx------ postgres postgres
```

### Issue 3: "No backups found"

```bash
# Verify backup repository has files
sudo -u postgres ls -la /mnt/pgbackrest-repo/demo/backup/

# If empty: Backups were never created
# Solution: Create first backup before restore
# (This is a chicken-and-egg problem - can't restore without backup)
```

### Issue 4: "backup status: error"

```bash
# Check backup status in detail
sudo -u postgres pgbackrest info --stanza=demo --verbose

# Look for: Any errors or corruption messages
# Solution: Run backup again to create new valid backup
```

## Verification Checklist

Complete this before proceeding to Step 2:

- [ ] `pgbackrest info` command runs without error
- [ ] At least one backup with `status: ok` exists
- [ ] Backup is not older than 7 days
- [ ] Backup repository is readable
- [ ] At least 100GB free disk space available
- [ ] Stanza name matches exactly (case-sensitive)
- [ ] All 3 nodes are accessible via SSH

## Summary

This step ensures you have a valid backup to restore from. If any verification fails, **do not proceed to Step 2** - diagnose and fix the issue first.

**Next:** Proceed to [02_STOP_PATRONI.md](02_STOP_PATRONI.md) once verification is complete.

---

**Troubleshooting:** If you have issues:
1. Check [../failure-analysis/FAILURE_MATRIX.md](../failure-analysis/FAILURE_MATRIX.md)
2. Review [../docs/TERMINOLOGY.md](../docs/TERMINOLOGY.md) for terms
3. See [../docs/QUICK_START.md](../docs/QUICK_START.md) for quick fixes
