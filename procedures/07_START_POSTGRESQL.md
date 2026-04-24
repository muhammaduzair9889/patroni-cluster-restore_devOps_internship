# Step 7: Start PostgreSQL for WAL Replay

**Purpose:** Start PostgreSQL manually to complete WAL recovery and bring database to consistent state.

**Estimated Time:** 3-5 minutes

**Difficulty:** Medium

**⚠️ Important:** Start PostgreSQL BEFORE Patroni, not after. This allows manual recovery to complete.

## Overview

PostgreSQL recovery process:
1. Read backup metadata (pg_control file)
2. Locate WAL files in pg_wal directory
3. Replay WAL files (execute transactions from backup to present)
4. Reach consistent state
5. Database ready for use

## Prerequisites

- Restore completed (Step 4)
- Files verified (Step 5)
- Permissions fixed (Step 6)
- PostgreSQL stopped
- Directory ready: /var/lib/postgresql/15/main/

## Procedure

### 7.1: Prepare for Manual Startup

```bash
# On PRIMARY node
ssh primary

# Create a log file to monitor recovery
mkdir -p /var/log/postgresql
sudo touch /tmp/postgres.log
sudo chown postgres:postgres /tmp/postgres.log
```

### 7.2: Start PostgreSQL Manually (Not as Service)

```bash
# Start PostgreSQL directly (not systemctl)
# This gives us more control and visibility
sudo -u postgres /usr/lib/postgresql/15/bin/pg_ctl start \
  -D /var/lib/postgresql/15/main \
  -l /tmp/postgres.log

# Expected output:
# waiting for server to start....
# done
# server started
```

### 7.3: Monitor WAL Recovery Progress

```bash
# Watch the log file (opens in follow mode)
sudo tail -f /tmp/postgres.log

# Expected output (will scroll):
# PostgreSQL 15.x on x86_64-pc-linux-gnu...
# Listening on IPv4 address "127.0.0.1", port 5432.
# LOG: starting recovery with redo LSN 1/...
# LOG: redo done at 1/... 
# LOG: last completed transaction was at 2026-04-14 12:00:00
# LOG: recovered prepared transactions for crash recovery
# LOG: autovacuum launcher started
# LOG: database system is ready to accept connections

# Press Ctrl+C when you see "ready to accept connections"
```

### 7.4: Verify PostgreSQL Started Successfully

```bash
# In another terminal, check if PostgreSQL is running
sudo -u postgres psql -c "SELECT version();"

# Expected output:
# PostgreSQL 15.x on x86_64-pc-linux-gnu, compiled by gcc...

# OR check with pg_ctl
sudo -u postgres /usr/lib/postgresql/15/bin/pg_ctl status \
  -D /var/lib/postgresql/15/main

# Expected: pg_ctl: server is running (PID: XXXXX)
```

### 7.5: Verify Database is Accessible

```bash
# Connect to database
sudo -u postgres psql -d postgres -c "SELECT datname FROM pg_database LIMIT 5;"

# Expected: Lists your databases
```

### 7.6: Check Replication Slots (Optional but Recommended)

```bash
# Verify replication infrastructure is ready
sudo -u postgres psql -c "SELECT slot_name, active FROM pg_replication_slots;"

# Expected: Empty or lists configured slots (OK if empty)
```

## Understanding WAL Recovery

### What Happens During Recovery

```
PostgreSQL starts
        │
        ▼
Read pg_control
├─ Database version
├─ System ID
├─ Recovery state
└─ Last known LSN position

        │
        ▼
Locate WAL files
├─ /var/lib/postgresql/15/main/pg_wal/
├─ Find first WAL file to replay
└─ Set recovery target

        │
        ▼
REPLAY WAL FILES (This takes time!)
├─ Read WAL file 000000010000000000000001
├─ Execute each transaction stored in WAL
├─ Build data pages
├─ Write to buffers
├─ Move to next WAL file
├─ Continue until all WAL processed
│
└─ (This is where time goes: 3-5 minutes typical)

        │
        ▼
Reach consistency point
├─ All transactions replayed
├─ Database at point-in-time
└─ Ready for connections

        │
        ▼
PostgreSQL ready
├─ Accepts connections
├─ Ready for writes
└─ Replication ready
```

## Timeline of Output

```
T+0s:   pg_ctl start ...
        waiting for server to start...

T+1s:   Listening on IPv4 address...
        
T+2s:   LOG: starting recovery with redo LSN 1/...
        LOG: redo done at 1/...
        (This is where WAL replay happens)

T+30s:  LOG: recovery complete!
        LOG: hot standby mode is active

T+40s:  LOG: ready to accept connections
        ← This is the important line!

Done!
```

## Verification Checklist

Complete before proceeding to Step 8:

- [ ] pg_ctl start completed successfully
- [ ] Log shows "ready to accept connections"
- [ ] psql can connect: `SELECT version();`
- [ ] No errors in recovery log
- [ ] Recovery completed in reasonable time (< 10 min)
- [ ] PostgreSQL status: running

## Common Issues & Fixes

### Issue 1: "FATAL: pre-existing shared memory block is still in use"

```bash
# Old PostgreSQL process still holding shared memory
# Clean it up
sudo ipcrm -a

# OR increase shared memory limits
sudo sysctl -w kernel.shmmax=1073741824
sudo sysctl -w kernel.shmall=262144

# Then retry
sudo -u postgres /usr/lib/postgresql/15/bin/pg_ctl start \
  -D /var/lib/postgresql/15/main \
  -l /tmp/postgres.log
```

### Issue 2: "FATAL: lock file '/var/lib/postgresql/15/main/postmaster.pid' exists"

```bash
# Stale PID file from previous crash
sudo rm /var/lib/postgresql/15/main/postmaster.pid

# Then retry start
sudo -u postgres /usr/lib/postgresql/15/bin/pg_ctl start \
  -D /var/lib/postgresql/15/main \
  -l /tmp/postgres.log
```

### Issue 3: "FATAL: failed to initialize any interfaces"

```bash
# Port 5432 already in use
# Find what's using it
sudo lsof -i :5432

# Kill the process or use different port
sudo killall -9 postgres

# Then retry
```

### Issue 4: Recovery is taking very long (> 10 minutes)

```bash
# Check progress
tail -f /tmp/postgres.log

# Check for errors:
sudo tail -50 /tmp/postgres.log | grep ERROR

# If "ERROR: recovery failed", see failure analysis docs
```

### Issue 5: "Could not open file '/var/lib/postgresql/15/main/pg_wal/...'"

```bash
# WAL file missing or corrupted
# Check what WAL files exist
sudo ls -la /var/lib/postgresql/15/main/pg_wal/ | head -20

# If WAL files missing: Restore didn't copy them
# Go back to Step 4 and re-run restore

# If WAL files exist but error persists:
# Try full restore instead of delta
```

## Monitoring with Another Terminal

```bash
# While recovery is happening, in another SSH session:

# Watch log
tail -f /tmp/postgres.log

# Check system load
watch -n 1 'top -bn1 | head -15'

# Check disk I/O
iostat -x 5

# Check PostgreSQL process
ps aux | grep postgres
```

## Recovery Complete! What's Next?

Once you see "ready to accept connections":

1. PostgreSQL is now running
2. Database recovered to backup point-in-time
3. All transactions replayed
4. Ready for replication
5. Proceed to Step 8 (Start Patroni)

## Stop PostgreSQL Before Patroni

When ready to proceed to Step 8:

```bash
# Stop the manually-started PostgreSQL
sudo -u postgres /usr/lib/postgresql/15/bin/pg_ctl stop \
  -D /var/lib/postgresql/15/main

# Verify stopped
sudo -u postgres /usr/lib/postgresql/15/bin/pg_ctl status \
  -D /var/lib/postgresql/15/main

# Expected: pg_ctl: no server running
```

## Summary

This step recovers the database from backup. PostgreSQL replays WAL files to bring the database to a consistent state. Once recovery completes, the database is ready for Patroni to take over.

**Next:** Proceed to [08_START_PATRONI.md](08_START_PATRONI.md) once PostgreSQL is stopped.

---

**Troubleshooting:** See [../failure-analysis/](../failure-analysis/)
