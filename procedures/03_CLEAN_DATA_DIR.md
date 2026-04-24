# Step 3: Clean Old Data Directory

**Purpose:** Remove old/corrupted data and prepare for fresh restore.

**Estimated Time:** 2 minutes

**Difficulty:** Easy

**⚠️ Warning:** This deletes the existing database. Only proceed after Patroni is stopped (Step 2 done).

## Overview

Before restoring, the data directory must be empty or backed up:
1. Rename old data directory (backup)
2. Create fresh empty directory
3. pgBackRest will populate it in Step 4

## Prerequisites

- Patroni stopped on all 3 nodes (Step 2 complete)
- PostgreSQL stopped (stopped in Step 2 or will be stopped here)
- At least 100GB free disk space

## Procedure

### 3.1: Ensure PostgreSQL is Stopped

```bash
# On PRIMARY node
ssh primary

# Check status
sudo systemctl status postgresql@15-main

# If running, stop it
sudo systemctl stop postgresql@15-main

# Verify stopped
sudo systemctl is-active postgresql@15-main
# Expected: inactive
```

### 3.2: Backup Old Data Directory (Safety)

```bash
# Rename old data directory to backup
sudo mv /var/lib/postgresql/15/main /var/lib/postgresql/15/main.backup-$(date +%Y%m%d-%H%M%S)

# Verify it's renamed
ls -la /var/lib/postgresql/15/
# Should show: main.backup-20260414-162530 (no "main" directory)
```

### 3.3: Create Fresh Empty Data Directory

```bash
# Create new empty directory
sudo mkdir -p /var/lib/postgresql/15/main

# Set correct permissions now (will be fixed again in Step 6)
sudo chown postgres:postgres /var/lib/postgresql/15/main
sudo chmod 0700 /var/lib/postgresql/15/main

# Verify
ls -la /var/lib/postgresql/15/
# Expected: drwx------ postgres postgres main
```

### 3.4: Verify Directory is Empty

```bash
# Check directory is truly empty
sudo ls -la /var/lib/postgresql/15/main/

# Expected: total 0 (only . and .. entries)
# If files exist: Something went wrong, investigate
```

### 3.5: Check Disk Space

```bash
# Verify sufficient free space for restore (at least 100GB)
df -h /var/lib/postgresql

# Expected: Lots of free space available
# Example:
# Filesystem      Size  Used Avail Use% Mounted on
# /dev/sda2       500G  250G  250G  50% /var/lib/postgresql
```

## Commands Summary

```bash
# One-liner approach
ssh primary << 'EOF'
  sudo systemctl stop postgresql@15-main
  sudo mv /var/lib/postgresql/15/main /var/lib/postgresql/15/main.backup-$(date +%Y%m%d-%H%M%S)
  sudo mkdir -p /var/lib/postgresql/15/main
  sudo chown postgres:postgres /var/lib/postgresql/15/main
  sudo chmod 0700 /var/lib/postgresql/15/main
  ls -la /var/lib/postgresql/15/main/
EOF
```

## Verification Checklist

Complete this before proceeding to Step 4:

- [ ] PostgreSQL stopped on primary
- [ ] Old data directory renamed to backup
- [ ] New empty data directory created
- [ ] Ownership: postgres:postgres
- [ ] Permissions: 0700
- [ ] At least 100GB free disk space
- [ ] Directory is empty (verified)

## Important Notes

⚠️ **Old data is backed up** - In case you need to recover
- Location: `/var/lib/postgresql/15/main.backup-TIMESTAMP`
- Only delete after confirming restore succeeded

⚠️ **Only done on PRIMARY node** - Replicas NOT cleaned
- Replicas will be cleaned during normal recovery process
- Or manually if needed (follow same steps)

⚠️ **Clean only when Patroni stopped**
- Prevents Patroni from interfering
- Prevents accidental cluster corruption

## Recovery if Something Goes Wrong

**If directory structure got messed up:**

```bash
# Restore from backup
sudo rm -rf /var/lib/postgresql/15/main
sudo mv /var/lib/postgresql/15/main.backup-* /var/lib/postgresql/15/main

# Fix permissions
sudo chown -R postgres:postgres /var/lib/postgresql/15/main
sudo chmod 0700 /var/lib/postgresql/15/main

# Restart Patroni (this aborts restore)
sudo systemctl start patroni
```

## Summary

This step removes the old data, preparing a clean slate for pgBackRest to restore the backup. The old data is safely backed up in case of problems.

**Next:** Proceed to [04_RUN_RESTORE.md](04_RUN_RESTORE.md) once directory is cleaned and verified.

---

**Troubleshooting:** See [../failure-analysis/FAILURE_MATRIX.md](../failure-analysis/FAILURE_MATRIX.md)
