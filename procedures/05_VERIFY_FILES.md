# Step 5: Verify Restored Files & Permissions

**Purpose:** Confirm restore was successful and files are properly in place.

**Estimated Time:** 2 minutes

**Difficulty:** Easy

## Overview

Before proceeding to WAL recovery, verify:
1. Data directory is populated
2. Critical files exist
3. File structure is intact
4. Disk space is reasonable

## Prerequisites

- Restore completed (Step 4 complete)
- Restore logged "restore complete" successfully
- Data directory shows ~50GB of files

## Procedure

### 5.1: Check Data Directory Size

```bash
# On PRIMARY node
ssh primary

# Check total data directory size
sudo du -sh /var/lib/postgresql/15/main/

# Expected: ~50GB (or your database size)
# If < 10GB: Restore may have failed - check log
# If = 0GB: Restore didn't run - run Step 4 again
```

### 5.2: Verify Critical Files Exist

```bash
# Check for critical PostgreSQL files
sudo ls -la /var/lib/postgresql/15/main/ | head -20

# Expected files:
# - base/               (table data)
# - global/             (roles, etc)
# - pg_wal/             (WAL files)
# - pg_control          (cluster metadata)
# - postgresql.conf     (or .auto.conf)
```

### 5.3: Verify pg_control File (Most Critical)

```bash
# This file is essential for recovery
sudo test -f /var/lib/postgresql/15/main/pg_control && echo "EXISTS" || echo "MISSING"

# Expected: EXISTS

# If missing, restore failed - debug and retry Step 4
```

### 5.4: Check Subdirectories

```bash
# Verify base/ directory (table data)
sudo ls -d /var/lib/postgresql/15/main/base/*/  | head -5

# Expected: Multiple directories (16385/, 16386/, etc)

# Verify pg_wal directory (WAL files)
sudo ls -la /var/lib/postgresql/15/main/pg_wal/ | head -10

# Expected: Multiple WAL files (000000010000000000000001, etc)
```

### 5.5: Verify File Ownership

```bash
# Check owner of data directory
ls -ld /var/lib/postgresql/15/main/

# Expected: drwx------ postgres postgres

# If owner is not postgres:postgres, Step 6 will fix it
```

### 5.6: Check Configuration Files

```bash
# Verify postgresql.conf or postgresql.auto.conf exists
sudo test -f /var/lib/postgresql/15/main/postgresql.conf && echo "EXISTS" || echo "MISSING"
sudo test -f /var/lib/postgresql/15/main/postgresql.auto.conf && echo "EXISTS" || echo "MISSING"

# At least one should exist
```

### 5.7: Verify pg_hba.conf and pg_ident.conf

```bash
# These are required for authentication
sudo ls -la /var/lib/postgresql/15/main/pg_*.conf

# Expected: pg_hba.conf, pg_ident.conf exist
```

## Detailed File Structure Check

```bash
# Run comprehensive check
sudo find /var/lib/postgresql/15/main -type f -name "pg_control" -o -name "PG_VERSION"

# Expected: Should find files
```

## Verification Checklist

Complete this before proceeding to Step 6:

- [ ] Data directory size: ~50GB
- [ ] pg_control file exists
- [ ] base/ directory populated
- [ ] pg_wal/ directory populated
- [ ] postgresql.conf exists
- [ ] pg_hba.conf exists
- [ ] pg_ident.conf exists
- [ ] File ownership: postgres:postgres
- [ ] Permissions look correct

## Common Issues & How to Fix

### Issue 1: Directory Size is 0 or Very Small

```bash
# Restore didn't work - verify with
sudo ls -la /var/lib/postgresql/15/main/

# If empty: Go back to Step 4 and re-run restore
# Check pgbackrest logs
sudo tail -30 /var/log/pgbackrest/demo-restore.log
```

### Issue 2: pg_control File Missing

```bash
# This is critical - restore failed
sudo ls -la /var/lib/postgresql/15/main/pg_control

# If not found: Restore was incomplete
# Solutions:
# 1. Check Step 4 log for errors
# 2. Clean data directory and retry Step 4
# 3. Try full restore instead of delta
```

### Issue 3: Wrong File Ownership

```bash
# If owner is root or someone else
sudo chown -R postgres:postgres /var/lib/postgresql/15/main

# Verify
ls -ld /var/lib/postgresql/15/main/
# Expected: postgres postgres
```

### Issue 4: Some Files are symlinks (OK)

```bash
# Some files might be symlinks - this is normal
sudo find /var/lib/postgresql/15/main -type l | head -10

# Symlinks are OK, they're handled correctly by PostgreSQL
```

## Advanced Verification

### Check PG_VERSION

```bash
# Verify PostgreSQL version matches
sudo cat /var/lib/postgresql/15/main/PG_VERSION

# Expected: 15 (or your version)
```

### Check Disk Usage by Directory

```bash
# See which subdirs consume most space
sudo du -sh /var/lib/postgresql/15/main/*/ | sort -hr | head -10

# Expected: base/ and pg_wal/ take most space
```

### Compare with Expected Size

```bash
# Get database size from before failure
# (This is what you expect)
# Typical: 50GB database = ~50GB restored

# If restored size significantly differs: Investigate
```

## Summary

This step verifies the restore completed successfully and all necessary files are in place. If any verification fails, the restore needs to be redone (Step 4).

**Next:** Proceed to [06_FIX_PERMISSIONS.md](06_FIX_PERMISSIONS.md) to ensure correct file ownership and permissions.

---

**Troubleshooting:** See [../failure-analysis/FAILURE_MATRIX.md](../failure-analysis/FAILURE_MATRIX.md)
