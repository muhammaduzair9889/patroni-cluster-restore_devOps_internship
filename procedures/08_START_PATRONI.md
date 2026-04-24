# Step 8: Start Patroni & Hand Control to Patroni

**Purpose:** Start Patroni service to resume HA cluster management.

**Estimated Time:** 1 minute

**Difficulty:** Easy

**⚠️ Important:** PostgreSQL must be stopped before Patroni starts (Step 7 complete).

## Overview

Patroni takes over cluster management:
1. Starts PostgreSQL (replaces manual startup)
2. Registers with etcd
3. Participates in leader election
4. Resumes replication coordination
5. Cluster becomes operational

## Prerequisites

- PostgreSQL stopped (from Step 7)
- etcd cluster running on all nodes
- Patroni stopped on all nodes (since Step 2)
- All three nodes accessible

## Procedure

### 8.1: Start Patroni on PRIMARY Node

```bash
# On PRIMARY node
ssh primary

# Start Patroni service
sudo systemctl start patroni

# Verify it started
sudo systemctl status patroni

# Expected: active (running)
```

### 8.2: Wait for Primary to Stabilize

```bash
# Patroni needs time to start PostgreSQL and register
sleep 10

# Check if PostgreSQL is running
sudo -u postgres psql -c "SELECT version();"

# Expected: Successfully connected
```

### 8.3: Start Patroni on REPLICA-1 Node

```bash
# On REPLICA-1 node
ssh replica-1

# Start Patroni
sudo systemctl start patroni

# Verify
sudo systemctl status patroni
# Expected: active (running)
```

### 8.4: Start Patroni on REPLICA-2 Node

```bash
# On REPLICA-2 node
ssh replica-2

# Start Patroni
sudo systemctl start patroni

# Verify
sudo systemctl status patroni
# Expected: active (running)
```

### 8.5: Verify Cluster is Forming

```bash
# Wait for leader election (30-60 seconds)
sleep 30

# Check cluster status
patronictl list

# Expected output:
# +-----------+----------+-----+---------+
# | Member    | Host     | Role| Status  |
# +-----------+----------+-----+---------+
# | primary   | 10.0.1.1 | L   | running |
# | replica-1 | 10.0.1.2 | ?   | running |
# | replica-2 | 10.0.1.3 | ?   | running |
# +-----------+----------+-----+---------+
#
# (? = sync state pending, will settle to F in 30 seconds)
```

## Timeline of Patroni Startup

```
T+0s:   systemctl start patroni (all 3 nodes)

T+5s:   Primary node:
        ├─ Patroni reads config
        ├─ Starts PostgreSQL
        └─ Registers with etcd as PRIMARY

T+10s:  Replica nodes:
        ├─ Patroni starts PostgreSQL
        ├─ Registers with etcd
        └─ Awaiting leader election result

T+15s:  etcd performs leader election:
        ├─ Votes between nodes
        ├─ Selects leader (usually primary)
        └─ Announces decision

T+20s:  Leader elected, replicas notified:
        ├─ Replicas learn new primary
        ├─ Connect replication stream
        └─ Begin streaming replication

T+30s:  Cluster stabilized:
        ├─ All nodes reporting status
        ├─ Replication active
        └─ Cluster operational!

T+60s:  Sync replication catches up:
        ├─ Replicas fully synchronized
        └─ Zero replication lag
```

## Verification Checklist

Complete before proceeding to Step 9:

- [ ] Patroni started on PRIMARY
- [ ] Patroni started on REPLICA-1
- [ ] Patroni started on REPLICA-2
- [ ] All services show "active (running)"
- [ ] patronictl list shows all 3 nodes
- [ ] One node has "L" (Leader)
- [ ] Other nodes have "F" (Follower)
- [ ] All statuses are "running"

## What If Leader Election Takes Too Long?

```bash
# Sometimes election takes 60-90 seconds
# Just wait and check periodically

# Monitor progress
for i in {1..10}; do
  echo "=== Attempt $i ($(date '+%H:%M:%S')) ==="
  patronictl list
  sleep 10
done

# Eventually you'll see:
# | primary   | 10.0.1.1 | L | running |
```

## Check PostgreSQL is Running Through Patroni

```bash
# Verify PostgreSQL started through Patroni
sudo systemctl status postgresql@15-main

# Expected: active (running)

# Verify you can connect
sudo -u postgres psql -c "SELECT version();"

# Expected: Returns PostgreSQL version
```

## Check Replication Status

```bash
# View connected replicas
sudo -u postgres psql -c "SELECT application_name, client_addr, state FROM pg_stat_replication;"

# Expected output (after replicas connect):
# application_name | client_addr | state
# -----------------+-------------+-------
# replica-1        | 10.0.1.2    | streaming
# replica-2        | 10.0.1.3    | streaming
#
# (May take 30 seconds for replicas to show up)
```

## Monitor Replication Lag

```bash
# Check replication lag
sudo -u postgres psql -c "SELECT application_name, write_lag, flush_lag, replay_lag FROM pg_stat_replication;"

# Expected:
# application_name | write_lag | flush_lag | replay_lag
# -----------------+-----------+-----------+----------
# replica-1        | null      | null      | null
# replica-2        | null      | null      | null
#
# (null = in sync, < 1s = healthy)
```

## Common Issues & Fixes

### Issue 1: Patroni fails to start

```bash
# Check Patroni logs
sudo journalctl -u patroni -n 50

# Common causes:
# - etcd not running: sudo systemctl start etcd
# - PostgreSQL already running: sudo systemctl stop postgresql
# - Configuration error: Check /etc/patroni/patroni.yml

# Retry
sudo systemctl start patroni
```

### Issue 2: No leader elected

```bash
# Check etcd status
sudo systemctl status etcd

# Check Patroni logs for election issues
sudo journalctl -u patroni -f

# If etcd is having issues:
sudo systemctl restart etcd

# Force patroni to retry election
sudo systemctl restart patroni
```

### Issue 3: PostgreSQL not running after Patroni starts

```bash
# Check Patroni logs
sudo journalctl -u patroni | grep ERROR

# Check PostgreSQL logs
sudo tail -30 /var/log/postgresql/postgresql-15-main.log

# Common causes:
# - Old shared memory: sudo ipcrm -a
# - Port in use: sudo lsof -i :5432
# - Permissions wrong: sudo chown -R postgres:postgres /var/lib/postgresql/15/main
```

### Issue 4: Replication not connecting

```bash
# Wait longer (30-60 seconds)
sleep 30
patronictl list

# If still not connected:
# Check network between nodes
ping replica-1
ping replica-2

# Check PostgreSQL logs
sudo tail -30 /var/log/postgresql/postgresql-15-main.log

# Check replication slots
sudo -u postgres psql -c "SELECT * FROM pg_replication_slots;"
```

## Manual Failover (If Needed)

You can test failover while verifying:

```bash
# Promote a replica (demote primary)
patronictl failover

# Follow prompts:
# - Choose which node to promote
# - Confirm demotion of current primary

# Cluster re-elects and stabilizes
```

## Monitoring Commands

```bash
# Watch cluster status continuously
watch -n 2 'patronictl list'

# Watch replication
watch -n 2 'psql -c "SELECT application_name, state FROM pg_stat_replication;"'

# Watch Patroni logs
sudo journalctl -u patroni -f
```

## Summary

Patroni is now managing the cluster again. PostgreSQL is running, replication is active (or activating), and the cluster should be back to normal operation.

**Next:** Proceed to [09_VERIFY_CLUSTER.md](09_VERIFY_CLUSTER.md) to perform final verification.

---

**Troubleshooting:** See [../failure-analysis/](../failure-analysis/)
