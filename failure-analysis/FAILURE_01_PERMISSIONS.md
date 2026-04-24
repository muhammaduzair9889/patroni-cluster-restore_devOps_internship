# Failure 1: Permission Denied on Repository

**Status:** RESOLVED

**Severity:** HIGH (Blocks restore immediately)

**Time to Resolve:** 30 seconds

## Failure Description

**Error Message:**
```
ERROR: unable to access '/mnt/pgbackrest-repo/demo': Permission denied
```

**When It Occurs:**
During Step 4 (Run Restore), when pgBackRest tries to read backup files from repository

**Initial Symptom:**
```bash
sudo -u postgres pgbackrest restore --stanza=demo --delta
ERROR: unable to access '/mnt/pgbackrest-repo/demo': Permission denied
Restore FAILED
```

## Root Cause Analysis

**Who Has Permissions:**
```bash
ls -ld /mnt/pgbackrest-repo/demo
drwxr-xr-x root root    ← Problem: Owned by root, not postgres
```

**Why It Fails:**
```
pgBackRest runs as: postgres user
Tries to access: /mnt/pgbackrest-repo/demo/
But directory owned by: root
And permissions are: 755 (root read/write, others read-only)

Result: postgres user cannot read/write repository
        Permission denied
```

## Solution

### Immediate Fix (30 seconds)

```bash
# Change ownership recursively
sudo chown -R postgres:postgres /mnt/pgbackrest-repo

# Change permissions (optional but recommended)
sudo chmod -R 0700 /mnt/pgbackrest-repo

# Verify fix
ls -ld /mnt/pgbackrest-repo
# Expected: drwx------ postgres postgres

# Retry restore
sudo -u postgres pgbackrest restore --stanza=demo --delta
```

### Why This Works

```
After fix:
ls -ld /mnt/pgbackrest-repo/demo
drwx------ postgres postgres    ← Now owned by postgres!

Now when pgBackRest runs:
├─ Process owner: postgres
├─ Directory owner: postgres
├─ Permissions: 0700 (owner can read/write)
├─ Can read/write: ✓
└─ Restore proceeds: ✓
```

## Prevention

### Pre-Restore Checklist

Add this to [../checklists/PRE_RESTORE_CHECKLIST.md](../checklists/PRE_RESTORE_CHECKLIST.md):

```
[ ] Verify repository ownership:
    ls -ld /mnt/pgbackrest-repo
    Expected: drwx------ postgres postgres
    
[ ] If wrong owner:
    sudo chown -R postgres:postgres /mnt/pgbackrest-repo
    sudo chmod -R 0700 /mnt/pgbackrest-repo
```

### Permanent Prevention

**In normal operations:**
1. Always store repository with postgres ownership
2. Include in infrastructure-as-code (Terraform, Ansible, etc.)
3. Verify ownership in health checks
4. Document as operational standard

**Example Ansible playbook:**
```yaml
- name: Ensure pgBackRest repo ownership
  file:
    path: /mnt/pgbackrest-repo
    owner: postgres
    group: postgres
    mode: '0700'
    recurse: yes
```

## Detection

**Automated detection (before restore):**
```bash
# Add to pre-restore checklist
REPO_OWNER=$(ls -ld /mnt/pgbackrest-repo | awk '{print $3}')
if [ "$REPO_OWNER" != "postgres" ]; then
  echo "ERROR: Repository not owned by postgres user"
  echo "Run: sudo chown -R postgres:postgres /mnt/pgbackrest-repo"
  exit 1
fi
```

## Impact Analysis

| Aspect | Impact |
|--------|--------|
| **Restore Status** | Completely blocked at Step 4 |
| **Downtime** | No progress until fixed |
| **Data Safety** | Not at risk (only permission issue) |
| **Recovery Time** | 30 seconds (trivial fix) |
| **Prevention Difficulty** | Easy (one chown command) |

## Similar Issues

**Same root cause, different paths:**
- `/mnt/pgbackrest-repo/` - Main repo
- `/var/log/pgbackrest/` - Log files
- `/etc/pgbackrest/` - Config files

**All should be readable by postgres user**

## Related Documentation

- Step 4: [../procedures/04_RUN_RESTORE.md](../procedures/04_RUN_RESTORE.md#issue-1-fatal-unable-to-access-mntpgbackrest-repo-permission-denied)
- Pre-restore checklist: [../checklists/PRE_RESTORE_CHECKLIST.md](../checklists/PRE_RESTORE_CHECKLIST.md)
- Permission fix: [../procedures/06_FIX_PERMISSIONS.md](../procedures/06_FIX_PERMISSIONS.md)

## Key Lessons

1. **pgBackRest runs as postgres user** - Repository must be accessible to postgres
2. **Permissions matter** - Even "world-readable" is insufficient
3. **Automation prevents** - Use config management to enforce ownership
4. **Quick to fix** - But could have been prevented

## Automation

See [../scripts/pre_restore_check.sh](../scripts/pre_restore_check.sh) for automated pre-restore verification including repository ownership check.
