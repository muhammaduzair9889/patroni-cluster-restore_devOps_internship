# LESSONS LEARNED - Key Insights from DEV291

## Critical Lessons from Real-World Experience

### 1. Repository Permissions ARE Critical

**Lesson:** postgres user MUST own the entire pgBackRest repository.

**Why:** pgBackRest runs as postgres user, needs to read/write backup files.

**What Happens When Wrong:**
```
Restore starts
     ↓
pgbackrest restore --stanza=demo
     ↓
Open repository: /mnt/pgbackrest-repo/demo/backup/
     ↓
ERROR: Permission denied
     ↓
Restore FAILS
```

**Fix:** `sudo chown -R postgres:postgres /mnt/pgbackrest-repo`

**Prevention:**
- Always verify ownership before restore: `ls -ld /mnt/pgbackrest-repo/`
- Include in pre-restore checklist
- Automate with configuration management
- Document in operational runbook

---

### 2. Stanza Names Are Case-Sensitive

**Lesson:** Stanza name in pgbackrest.conf MUST match exactly (case matters).

**The Error:** 
```bash
# Config has:
[Demo]          ← Uppercase D

# But command uses:
pgbackrest info --stanza=demo    ← Lowercase d

# Result:
ERROR: stanza 'demo' not found in pgbackrest.conf
```

**Prevention:**
- Always use lowercase stanza names: `[demo]` not `[Demo]`
- Document stanza name in runbook
- Verify in pre-restore checklist
- Check both config AND commands

**Tip:** Use consistent naming across all systems:
```
Good:  [demo], [prod], [staging]
Bad:   [Demo], [PROD], [Staging]
```

---

### 3. System Identifier Mismatch Blocks Patroni

**Lesson:** PostgreSQL system ID must match across cluster OR be cleared from etcd.

**What Happens:**
```
Restore completes
     ↓
Start Patroni
     ↓
PostgreSQL starts with NEW system ID (from restore)
     ↓
Patroni checks etcd: "What's this cluster's system ID?"
     ↓
etcd says: "Should be X" (old ID from before failure)
     ↓
PostgreSQL says: "I am Y" (new ID from restore)
     ↓
MISMATCH! → FATAL ERROR
Patroni fails to start
```

**Fix:** Clear etcd metadata before restore:
```bash
sudo etcdctl del /service/patroni/cluster_name --prefix
```

**Prevention:**
- Include etcd cleanup in Step 2 (Stop Patroni)
- Document in runbook
- Automate if possible
- Add to pre-restore checklist

---

### 4. Stop Patroni on ALL Nodes Simultaneously

**Lesson:** Must stop on all 3 nodes at same time to prevent split-brain.

**What Happens If You Don't:**
```
Stop Patroni on Primary: ✓
Stop Patroni on Replica-1: ✓
Don't stop on Replica-2: ✗

Result: Replica-2 still running, thinks primary is down
        Triggers leader election
        Replica-2 might elect itself as new primary
        Now you have TWO primaries accepting writes
        DATA CORRUPTION → Impossible to recover
```

**Prevention:**
- Use parallel SSH: `ssh node1 "..." & ssh node2 "..." & ssh node3 "..."`
- Verify all 3 stopped before proceeding
- Include in checklist
- Automate with scripts

---

### 5. Delta Restore is Faster AND Safer

**Lesson:** Always use `--delta` flag for restore.

**Why:**
- Faster: Only copies changed files (5 min vs 15 min)
- Safer: Doesn't delete existing files
- Recoverable: Can retry without full wipe

**Without --delta:**
```
pgbackrest restore --stanza=demo
     ↓
Remove ALL files in data directory
     ↓
Restore from backup
     ↓
If fails halfway: All data GONE
```

**With --delta:**
```
pgbackrest restore --stanza=demo --delta
     ↓
Compare backup vs current
     ↓
Only copy files that differ
     ↓
If fails: Can retry
```

**Recommendation:** Always use `--delta` unless specifically advised otherwise.

---

### 6. WAL Recovery Takes Time - Be Patient

**Lesson:** WAL replay during recovery can take 3-10 minutes even if other steps are fast.

**What Happens:**
```
pgBackRest restore: 5 minutes ✓
Fix permissions: 1 minute ✓
Start PostgreSQL: 1 minute... waiting...
                  2 minutes... replaying WAL...
                  3 minutes... still replaying...
                  4 minutes... getting there...
                  5 minutes... DONE
```

**Why:** PostgreSQL must:
1. Read EVERY transaction from WAL
2. Apply EVERY transaction to data
3. Verify integrity at each step
4. Cannot skip or parallelize much

**Impacts:**
- Total restore time: 20-30 minutes
- Cannot interrupt recovery
- Must wait for consistency
- No shortcuts available

**Prevention:**
- Set realistic expectations
- Plan restore during maintenance window
- Allow extra time (prepare for 1 hour)
- Monitor log, don't panic if it takes time

---

### 7. pgBackRest Info Output is Your Friend

**Lesson:** Always run `pgbackrest info` before restore and document output.

**What You Learn:**
```bash
pgbackrest info
     ↓
Shows:
├─ Stanza name (verify correct)
├─ Backup status (must be "ok")
├─ All available backups (choose wisest)
├─ Database version (ensure compatibility)
├─ System identifier (might change during restore)
└─ Backup timestamps (know what you're restoring to)
```

**Before Restore, You Should Know:**
- [x] Latest backup is < 7 days old
- [x] Backup status is "ok"
- [x] Backup size matches expected database size
- [x] All parent backups available (for full+diff+incr chains)

**Troubleshooting Tip:**
```
Problem: Restore fails
Solution: Check pgbackrest info output
          Does it show backup status as "ok"?
          If not: Backup itself is corrupt - cannot restore
```

---

### 8. Disk Space Management is Essential

**Lesson:** Need space for: Original DB + Compressed Backup + Restored copy = 100+ GB.

**Space Calculation:**
```
Database size:              50GB
Original data before wipe:  50GB (keep as backup)
Restore in progress:        50GB (working area)
Plus overhead:              10GB
─────────────────────────────────
Recommended free space:     150GB minimum
Safe to have:               200GB free
```

**What Happens If You Run Out:**
```
Restore 60% complete: 30GB written
     ↓
Disk full!
     ↓
pgBackRest crashes
     ↓
Data directory: Partially populated + corrupted
     ↓
Recovery: Start over, clean disk, retry
```

**Prevention:**
- Check disk space BEFORE restoring: `df -h`
- Have plan to free space if needed
- Consider archiving old backups if repository full
- Monitor during restore

---

### 9. Test Restore Procedures Regularly

**Lesson:** You don't really know your restore works until you test it.

**The Problem:**
```
"Our backups are good because backups run every night"
           ↓
Cluster fails
           ↓
Try to restore
           ↓
"Wait... this config is wrong"
           ↓
"The backup is corrupted"
           ↓
"I forgot how to do this"
           ↓
PANIC
```

**The Solution:**
```
Monthly: Perform restore drill
├─ Use sandbox environment (not production)
├─ Restore from actual backup
├─ Verify database integrity
├─ Time the process
├─ Document problems
├─ Update runbook
└─ Repeat next month
```

**Benefits:**
- Discover configuration issues BEFORE real failure
- Learn the procedure by doing it
- Identify automation opportunities
- Build confidence in recovery
- Update timing estimates

---

### 10. Automate Everything Possible

**Lesson:** Manual processes are error-prone. Automate the 9-step restore.

**Why Automate:**
```
Manual restore:
├─ Takes 30 minutes (if no errors)
├─ Requires 2-3 experienced admins
├─ Error-prone (forgot a step?)
├─ Hard to reproduce exactly
├─ Knowledge lives in person's head
└─ During disaster: Panic and mistakes

Automated restore:
├─ Takes 20-25 minutes (auto optimized)
├─ Requires 1 person to press button
├─ Consistent every time
├─ Exact same steps
├─ Knowledge in script
└─ During disaster: Confidence
```

**What to Automate:**
1. Pre-restore validation (check backups, permissions)
2. Stop Patroni on all nodes
3. Clean data directories
4. Run pgBackRest restore
5. Fix permissions
6. Start PostgreSQL and wait for recovery
7. Start Patroni and verify cluster
8. Generate restoration report

**See:** [../scripts/restore_cluster.sh](../scripts/restore_cluster.sh)

---

## Best Practices Derived from Failures

### Before Restore
1. ✅ Run `pgbackrest info` and save output
2. ✅ Check disk space: `df -h` (need 150GB free)
3. ✅ Test network access to all 3 nodes
4. ✅ Verify etcd is healthy: `etcdctl cluster-health`
5. ✅ Document expected database size
6. ✅ Notify stakeholders (will be downtime)
7. ✅ Have recent backup of pg_control (just in case)

### During Restore
1. ✅ Monitor all steps (don't walk away)
2. ✅ Check logs frequently for errors
3. ✅ Watch disk space fill up (should match database size)
4. ✅ Be patient during WAL recovery (takes time)
5. ✅ Note any unusual messages for post-mortem

### After Restore
1. ✅ Verify ALL 3 nodes online
2. ✅ Check replication working
3. ✅ Run test queries
4. ✅ Monitor logs for errors (10 minutes)
5. ✅ Document restore process and time taken
6. ✅ Update runbook with any lessons
7. ✅ Schedule next restore drill (for next month)

---

## Metrics & Expectations

### Typical Restore Times
```
Step 1 - Check Backups:         2 min
Step 2 - Stop Patroni:          1 min
Step 3 - Clean Data Dir:        2 min
Step 4 - Run Restore:           5-10 min   ← Varies with size
Step 5 - Verify Files:          2 min
Step 6 - Fix Permissions:       1 min
Step 7 - Start PostgreSQL:      3-5 min    ← WAL recovery varies
Step 8 - Start Patroni:         1 min
Step 9 - Verify Cluster:        3 min
────────────────────────────────
Total:                          20-30 min
```

### Resource Usage During Restore
```
CPU:        60-80% (pgBackRest uses all cores)
Memory:     4-8GB (out of 16GB available)
Disk I/O:   100-150 MB/sec (saturates disk)
Network:    50-100 MB/sec (if NFS repository)
```

---

## Key Takeaways

1. **Restore is NOT mysterious** - It's a predictable 9-step process
2. **Small details matter** - Permissions, stanza names, system IDs
3. **Automation is key** - Manual is error-prone
4. **Testing is essential** - Know your restore before you need it
5. **Documentation is power** - Write everything down
6. **Monitoring is mandatory** - Watch the process
7. **Time estimates help** - Plan for 30 minutes plus contingency
8. **Failures teach lessons** - Document them
9. **Practice regularly** - Monthly restore drills
10. **Communicate clearly** - Tell stakeholders about downtime

---

## Recommended Reading Order

1. This file (lessons learned) - 10 min
2. [../IMPROVEMENTS.md](../IMPROVEMENTS.md) - Recommended enhancements
3. [../failure-analysis/](../failure-analysis/) - Real failures and fixes
4. [../procedures/](../procedures/) - Step-by-step walkthrough
5. [../scripts/restore_cluster.sh](../scripts/restore_cluster.sh) - Automation

---

**Next:** See [../IMPROVEMENTS.md](../IMPROVEMENTS.md) for recommendations on improving this process.
