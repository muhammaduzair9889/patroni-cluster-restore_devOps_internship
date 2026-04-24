# Step 2: Stop Patroni Safely

**Purpose:** Stop Patroni on ALL nodes to prevent cluster conflicts during restore.

**Estimated Time:** 1 minute

**Difficulty:** Easy

**⚠️ Critical:** Must stop on ALL 3 nodes simultaneously to prevent split-brain scenarios.

## Overview

Patroni must be stopped before restore because:
1. Prevents Patroni from interfering with restore process
2. Prevents "split-brain" condition (multiple primaries)
3. Allows manual control of PostgreSQL
4. Prevents automatic failover during restore

## Prerequisites

- SSH access to all 3 nodes (primary, replica-1, replica-2)
- Backup verification complete (Step 1 done)
- Current database is NOT critical (already failed)

## Procedure

### 2.1: Stop Patroni on Primary Node

```bash
# On PRIMARY node
ssh primary

# Check status
sudo systemctl status patroni

# Stop Patroni
sudo systemctl stop patroni

# Verify stopped
sudo systemctl status patroni
# Expected: inactive (dead)
```

### 2.2: Stop Patroni on Replica Node 1

```bash
# On REPLICA-1 node
ssh replica-1

# Stop Patroni
sudo systemctl stop patroni

# Verify stopped
sudo systemctl status patroni
# Expected: inactive (dead)
```

### 2.3: Stop Patroni on Replica Node 2

```bash
# On REPLICA-2 node
ssh replica-2

# Stop Patroni
sudo systemctl stop patroni

# Verify stopped
sudo systemctl status patroni
# Expected: inactive (dead)
```

### 2.4: Verify PostgreSQL is Still Running (Optional Stop)

After stopping Patroni, PostgreSQL might still be running. You have two options:

**Option A: Let PostgreSQL continue (will stop naturally during restore)**
```bash
# Check if PostgreSQL is running
sudo systemctl status postgresql@15-main

# If running and you want to leave it:
# It will stop when we clean the data directory in Step 3
```

**Option B: Stop PostgreSQL now**
```bash
# Stop PostgreSQL immediately
sudo systemctl stop postgresql@15-main

# Verify
sudo systemctl status postgresql@15-main
# Expected: inactive (dead)
```

**Recommendation:** Option A is preferred - let PostgreSQL stop naturally in Step 3.

## Commands Summary (All at Once)

If you prefer one-liner approach:

```bash
# Stop on all 3 nodes in parallel
ssh primary "sudo systemctl stop patroni" &
ssh replica-1 "sudo systemctl stop patroni" &
ssh replica-2 "sudo systemctl stop patroni" &
wait

# Verify on all 3 nodes
ssh primary "sudo systemctl status patroni" | grep inactive
ssh replica-1 "sudo systemctl status patroni" | grep inactive
ssh replica-2 "sudo systemctl status patroni" | grep inactive

# All three should show: inactive (dead)
```

## Verification Checklist

Complete this before proceeding to Step 3:

- [ ] Patroni stopped on PRIMARY node
- [ ] Patroni stopped on REPLICA-1 node
- [ ] Patroni stopped on REPLICA-2 node
- [ ] All nodes show `inactive (dead)`
- [ ] PostgreSQL may still be running (OK)
- [ ] etcd cluster still running (required)

## Important Notes

⚠️ **Do NOT disable or stop etcd** - Still needed for cluster state
- Keep etcd running on all nodes
- Patroni is stopped, but etcd continues
- When we restart Patroni in Step 8, it will need etcd

⚠️ **PostgreSQL may still be running**
- Don't manually stop it if Patroni stops it
- If it's still running, it will be killed in Step 3 when we clean data dir

⚠️ **This is Point of No Return**
- After stopping Patroni, cluster is no longer managed
- Old primary node (if available) must NOT connect to cluster
- Continue with Steps 3-9 to complete restore

## Common Issues & Fixes

### Issue: "Failed to stop patroni: Unit patroni.service not found"

```bash
# Patroni may not be installed as service
# Check if Patroni is running
sudo ps aux | grep patroni

# If running: Kill it
sudo killall patroni

# If not running: Continue to Step 3
```

### Issue: PostgreSQL won't stop

```bash
# If PostgreSQL is stuck
sudo systemctl kill postgresql@15-main

# Check if it's really stopped
sudo ps aux | grep postgres
```

### Issue: Need to restart Patroni (Abort Restore)

If you need to abort the restore and restart Patroni:

```bash
# On all 3 nodes
sudo systemctl start patroni

# Wait for cluster to stabilize (30 seconds)
sleep 30

# Verify cluster
patronictl list
```

## Summary

This step safely stops Patroni cluster management, allowing manual control of the restore process. All three nodes must have Patroni stopped to prevent conflicts.

**Next:** Proceed to [03_CLEAN_DATA_DIR.md](03_CLEAN_DATA_DIR.md) once all nodes confirm Patroni is stopped.

---

**Troubleshooting:** See [../failure-analysis/FAILURE_MATRIX.md](../failure-analysis/FAILURE_MATRIX.md)
