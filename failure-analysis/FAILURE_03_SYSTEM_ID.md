# Failure 3: Patroni Fails to Start - System Identifier Mismatch

**Status:** RESOLVED

**Severity:** CRITICAL (Blocks cluster recovery)

**Time to Resolve:** 2 minutes

## Failure Description

**Error Message:**
```
FATAL: cluster identifier system identifier mismatch
PostgreSQL system identifier does not match cluster system identifier
```

**When It Occurs:**
Step 8 (Start Patroni) - After successful restore but before cluster recovery

**Initial Symptom:**
```bash
sudo systemctl start patroni

# Check status
sudo systemctl status patroni
# Shows: failed
# Error in logs: System identifier mismatch

# Patroni fails to start
# PostgreSQL won't start through Patroni
# Manual PostgreSQL might be running but Patroni won't manage it
```

## Root Cause Analysis

**The Problem:**
```
Before cluster failure:
├─ PostgreSQL system ID: 12345 (unique to this cluster)
├─ etcd stores: system_id = 12345
└─ Everything synchronized

Restore happens:
├─ pgBackRest restores backup
├─ Backup created with system ID: 12345
├─ BUT data files are COPIED, not the pg_control metadata
└─ PostgreSQL now has system ID: 12345 (OK so far)

But wait - NEW database data = NEW system ID generated?
├─ NO - restore copies pg_control with same ID
└─ System ID should match

However - in some scenarios:
├─ Database initialized as new cluster
├─ New system ID generated: 67890
├─ Different from old ID: 12345

Patroni starts and:
├─ Reads PostgreSQL system ID: 67890 (from pg_control)
├─ Checks etcd for cluster ID: 12345 (old metadata)
├─ MISMATCH! 67890 ≠ 12345
├─ FATAL ERROR: Cannot proceed
└─ Patroni refuses to start
```

## Solution

### Immediate Fix (2 minutes)

**Step 1: Clear etcd cluster metadata**

```bash
# Clear ALL cluster metadata from etcd
sudo etcdctl del /service/patroni/cluster_name --prefix

# Or clear specific key patterns
sudo etcdctl del /service/demo --prefix

# Verify cleared
sudo etcdctl ls /service/demo 2>/dev/null || echo "Cleared successfully"
```

**Step 2: Wait a moment for cleanup**

```bash
sleep 5
```

**Step 3: Start Patroni**

```bash
# Primary node
sudo systemctl start patroni

# Wait for initialization
sleep 30

# Check status
patronictl list
```

**Expected Result:**
```
Patroni starts fresh
├─ Initializes cluster in etcd with NEW system ID
├─ PostgreSQL starts
├─ Leader election occurs
└─ Cluster operational!
```

## Prevention

### In-Procedure Prevention

**Add to Step 2 (Stop Patroni) procedure:**

```bash
# Before stopping Patroni, clear cluster metadata from etcd
sudo etcdctl del /service/patroni/cluster_name --prefix

# Wait a moment
sleep 2

# Then stop Patroni normally
sudo systemctl stop patroni
```

### Pre-Restore Checklist

```
[ ] Document current system identifier:
    sudo -u postgres pg_controldata /var/lib/postgresql/15/main | grep "Database system identifier"
    
[ ] After restore, verify system ID changed (if restore was successful)
    
[ ] If Patroni fails to start with system ID mismatch:
    sudo etcdctl del /service/demo --prefix
    sudo systemctl start patroni
```

## Detection

**Automated detection:**
```bash
#!/bin/bash
# Check for system identifier mismatch

POSTGRES_ID=$(sudo -u postgres pg_controldata /var/lib/postgresql/15/main 2>/dev/null | grep "Database system identifier" | awk '{print $NF}')

ETCD_ID=$(sudo etcdctl get /service/demo/initialize 2>/dev/null | grep system_identifier || echo "not found")

echo "PostgreSQL system ID: $POSTGRES_ID"
echo "etcd system ID: $ETCD_ID"

if [ -n "$POSTGRES_ID" ] && [ -n "$ETCD_ID" ]; then
  if [ "$POSTGRES_ID" != "$ETCD_ID" ]; then
    echo "ERROR: System identifier mismatch!"
    echo "FIX: sudo etcdctl del /service/demo --prefix"
  fi
fi
```

## Why This Matters

**System Identifier is critical:**
```
It's like a "birth certificate" for the cluster
├─ Generated when cluster first initialized
├─ Must be same on all nodes in cluster
├─ Stored in pg_control file
├─ Stored in etcd by Patroni
├─ Used to verify replicas belong to same cluster

If mismatch:
├─ Replica could connect to wrong primary
├─ Data could be mixed from different clusters
├─ Data corruption risk
└─ Patroni rejects to prevent disaster
```

## Real-World Scenarios

**Scenario 1: Restore from different backup**
```
Original cluster: System ID 111
Restore from backup of different cluster: System ID 222
Result: System ID mismatch error
```

**Scenario 2: Stale etcd metadata**
```
Old cluster: System ID 111 (stored in etcd)
New cluster: System ID 222 (in PostgreSQL after restore)
Result: Mismatch until etcd cleared
```

**Scenario 3: Sandbox restore**
```
Production: System ID 111
Restore to sandbox: System ID 222 (new cluster)
Expected: Mismatch error (normal for sandbox)
Fix: Clear etcd metadata
```

## Impact Analysis

| Aspect | Impact |
|--------|--------|
| **Recovery Status** | Patroni won't start (blocks cluster recovery) |
| **Downtime** | Cluster unavailable until etcd cleared |
| **Data Safety** | Safe (prevent wrong replica connection) |
| **Time to Fix** | 2 minutes |
| **Prevention Difficulty** | Easy (one command) |

## Related Documentation

- Step 2: [../procedures/02_STOP_PATRONI.md](../procedures/02_STOP_PATRONI.md)
- Step 8: [../procedures/08_START_PATRONI.md](../procedures/08_START_PATRONI.md#issue-2-no-leader-elected)
- Terminology: [../docs/TERMINOLOGY.md#system-identifier](../docs/TERMINOLOGY.md)

## Key Lessons

1. **System ID is sacred** - Must match across cluster
2. **etcd stores metadata** - Stale metadata causes problems
3. **Clear etcd for sandbox** - When restoring to new environment
4. **Document before restore** - Note current system ID
5. **Prevention is easy** - Just one command

## Automation

```bash
#!/bin/bash
# Post-restore sanity check

echo "Checking system identifier consistency..."

PRIMARY_ID=$(ssh primary "sudo -u postgres pg_controldata /var/lib/postgresql/15/main | grep 'Database system identifier'" | awk '{print $NF}')
REPLICA1_ID=$(ssh replica-1 "sudo -u postgres pg_controldata /var/lib/postgresql/15/main | grep 'Database system identifier'" | awk '{print $NF}')
REPLICA2_ID=$(ssh replica-2 "sudo -u postgres pg_controldata /var/lib/postgresql/15/main | grep 'Database system identifier'" | awk '{print $NF}')

echo "Primary ID: $PRIMARY_ID"
echo "Replica-1 ID: $REPLICA1_ID"
echo "Replica-2 ID: $REPLICA2_ID"

if [ "$PRIMARY_ID" = "$REPLICA1_ID" ] && [ "$PRIMARY_ID" = "$REPLICA2_ID" ]; then
  echo "✓ All system identifiers match!"
else
  echo "✗ System identifier mismatch detected!"
  echo "This should not happen - investigate immediately"
fi
```
