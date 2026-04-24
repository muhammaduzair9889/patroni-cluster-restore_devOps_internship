# Failure Analysis - Real-World Problems & Solutions

This section documents real failures encountered during Patroni cluster restoration.

## Failures Covered

### Failure 1: Permission Denied on Repository
**File:** [FAILURE_01_PERMISSIONS.md](FAILURE_01_PERMISSIONS.md)

**Error:**
```
ERROR: unable to access '/mnt/pgbackrest-repo/demo': Permission denied
```

**Root Cause:** Repository owned by root, postgres user lacks read/write permissions

**Solution:** Change ownership to postgres:postgres recursively

**Prevention:** Include in pre-restore checklist

---

### Failure 2: Stanza Configuration Mismatch
**File:** [FAILURE_02_STANZA.md](FAILURE_02_STANZA.md)

**Error:**
```
ERROR: stanza 'demo' not found in pgbackrest.conf
```

**Root Cause:** Config has `[Demo]` (uppercase) but command uses `--stanza=demo` (lowercase)

**Solution:** Fix stanza name to match exactly (case-sensitive)

**Prevention:** Use lowercase consistently, document in runbook

---

### Failure 3: Patroni Fails to Start After Restore
**File:** [FAILURE_03_SYSTEM_ID.md](FAILURE_03_SYSTEM_ID.md)

**Error:**
```
FATAL: cluster identifier system identifier mismatch
```

**Root Cause:** PostgreSQL system ID in pg_control changed after restore; Patroni detected mismatch with etcd metadata

**Solution:** Clear stale cluster metadata from etcd, let Patroni re-bootstrap

**Prevention:** Clean etcd metadata before restore, document in procedures

---

## Failure Matrix
**File:** [FAILURE_MATRIX.md](FAILURE_MATRIX.md)

Quick reference table of common failures with:
- Error message
- Root cause
- Quick fix
- Prevention steps
- Related documentation

---

## How to Use This Section

1. **Encounter an error?** → Check FAILURE_MATRIX.md for quick fix
2. **Want to understand failure?** → Read the specific failure file
3. **Prevent future failures?** → Follow Prevention section
4. **Debug complex issue?** → Review failure analysis + logs

---

## Common Error Messages (Quick Index)

| Error | File | Fix Time |
|-------|------|----------|
| Permission denied | FAILURE_01 | 30 sec |
| Stanza not found | FAILURE_02 | 1 min |
| System ID mismatch | FAILURE_03 | 2 min |
| (See FAILURE_MATRIX for more) | ... | ... |

---

**Note:** These failures are from real restore attempts. Each includes:
- How the failure manifested
- What caused it
- How to recognize it
- How to fix it
- How to prevent it
- Related procedures
