# Step 6: Fix File Permissions

**Purpose:** Ensure PostgreSQL user (postgres) owns all data files.

**Estimated Time:** 1 minute

**Difficulty:** Easy

**⚠️ Critical:** PostgreSQL cannot start if ownership is incorrect.

## Overview

PostgreSQL requires:
1. **Owner:** postgres user (UID 26)
2. **Group:** postgres group (GID 26)
3. **Permissions:** 0700 for directories, 0600 for files

If ownership is wrong, PostgreSQL will fail with "Permission denied" errors.

## Prerequisites

- Restore completed and verified (Steps 4-5 complete)
- User: postgres exists on system
- Group: postgres exists on system

## Procedure

### 6.1: Fix Ownership (Recursively)

```bash
# On PRIMARY node
ssh primary

# Change owner to postgres:postgres recursively
sudo chown -R postgres:postgres /var/lib/postgresql/15/main

# This command:
# - Changes owner to 'postgres' user
# - Changes group to 'postgres' group
# - Applies recursively to all files/folders (-R flag)
# - Takes 10-30 seconds for 50GB
```

### 6.2: Fix Permissions (Recursively)

```bash
# Fix directory permissions (0700)
sudo find /var/lib/postgresql/15/main -type d -exec chmod 0700 {} \;

# Fix file permissions (0600)
sudo find /var/lib/postgresql/15/main -type f -exec chmod 0600 {} \;

# Alternative (simpler but less precise):
sudo chmod -R u=rwX,g=,o= /var/lib/postgresql/15/main
```

### 6.3: Verify Permissions on Root Directory

```bash
# Check main data directory
ls -ld /var/lib/postgresql/15/main/

# Expected: drwx------ postgres postgres
# Meaning:
#   d       = directory
#   rwx     = owner (postgres) can read/write/execute
#   ---     = group (postgres) has NO permissions
#   ---     = others have NO permissions
#   postgres postgres = owner:group
```

### 6.4: Spot-Check Sample Files

```bash
# Check permissions on a few files
sudo ls -la /var/lib/postgresql/15/main/pg_control

# Expected: -rw------- postgres postgres
# Meaning:
#   -       = regular file
#   rw-     = owner (postgres) can read/write
#   ---     = group has no permissions
#   ---     = others have no permissions

# Check a table file
sudo ls -la /var/lib/postgresql/15/main/base/16385/* | head -3

# Expected: similar to above (-rw------- postgres postgres)
```

## Commands Summary (All in One)

```bash
# One-liner approach
ssh primary << 'EOF'
  echo "Fixing ownership..."
  sudo chown -R postgres:postgres /var/lib/postgresql/15/main
  echo "Fixing permissions..."
  sudo find /var/lib/postgresql/15/main -type d -exec chmod 0700 {} \;
  sudo find /var/lib/postgresql/15/main -type f -exec chmod 0600 {} \;
  echo "Verifying..."
  ls -ld /var/lib/postgresql/15/main/
EOF
```

## Verification Checklist

Complete this before proceeding to Step 7:

- [ ] Ownership changed: postgres:postgres
- [ ] Directory permissions: 0700
- [ ] File permissions: 0600
- [ ] pg_control: postgres postgres ownership
- [ ] All files verified
- [ ] No permission errors in output

## Quick Verification Script

```bash
# Verify all critical points
bash << 'EOF'

echo "=== Data Directory Ownership ==="
ls -ld /var/lib/postgresql/15/main/
echo

echo "=== Sample File Ownership ==="
sudo ls -la /var/lib/postgresql/15/main/pg_control
echo

echo "=== Permission Check ==="
# Should show all 0700 and 0600
sudo find /var/lib/postgresql/15/main -type f | head -3 | xargs ls -la
echo

echo "=== All checks complete ==="

EOF
```

## Troubleshooting

### Issue 1: "Operation not permitted"

```bash
# You might not have sudo access
# Try with explicit sudo
sudo chown -R postgres:postgres /var/lib/postgresql/15/main

# If still fails: You need root/sudo access
```

### Issue 2: "postgres: unknown user"

```bash
# postgres user doesn't exist
# Create it:
sudo useradd -r -s /bin/bash postgres

# Then retry chown command
```

### Issue 3: Ownership is correct but permissions wrong

```bash
# Verify current permissions
sudo ls -la /var/lib/postgresql/15/main/pg_control

# Fix if needed
sudo chmod 0600 /var/lib/postgresql/15/main/pg_control

# For all files
sudo find /var/lib/postgresql/15/main -type f -exec chmod 0600 {} \;
```

## Why This Matters

```
If ownership is WRONG:

START PostgreSQL
     │
     ▼
PostgreSQL reads: /var/lib/postgresql/15/main/pg_control
     │
     ├─ File owner: root (not postgres user)
     ├─ Owned by: root:root
     ├─ Permissions: 0644 (world readable)
     │
     ▼
ERROR: Permission denied
Cannot read pg_control
PostgreSQL startup FAILS


If ownership is CORRECT:

START PostgreSQL
     │
     ▼
PostgreSQL reads: /var/lib/postgresql/15/main/pg_control
     │
     ├─ File owner: postgres (correct!)
     ├─ Owned by: postgres:postgres
     ├─ Permissions: 0600 (postgres only)
     │
     ▼
SUCCESS: Reads pg_control
Starts recovery
PostgreSQL startup SUCCEEDS
```

## Performance Note

Fixing permissions on 50GB may take 30-60 seconds. Don't interrupt it.

```bash
# Monitor progress
watch -n 2 "ls -la /var/lib/postgresql/15/main/ | head -5"
```

## Summary

This step ensures PostgreSQL can read and write its data files. Without correct ownership, PostgreSQL cannot start, and the restore fails.

**Next:** Proceed to [07_START_POSTGRESQL.md](07_START_POSTGRESQL.md) to start PostgreSQL and complete WAL recovery.

---

**Troubleshooting:** See [../failure-analysis/FAILURE_01_PERMISSIONS.md](../failure-analysis/FAILURE_01_PERMISSIONS.md)
