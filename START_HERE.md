# START HERE - DEV291: Patroni Cluster Restore Guide

Welcome! This guide will help you understand and execute a **Patroni cluster restoration** process from a pgBackRest backup.

## 🎯 What You'll Learn

In approximately **30 minutes**, you can:
1. Understand how Patroni HA clusters work
2. Learn the 9-step restoration process
3. Identify and resolve common failures
4. Validate your cluster health after restore

## ⏱️ Time Breakdown

| Activity | Duration | File |
|----------|----------|------|
| Read this guide | 5 min | This page |
| Learn architecture | 10 min | [architecture/](../architecture/) |
| Execute restore | 20-30 min | [procedures/](../procedures/) |
| Verify cluster | 5 min | [checklists/POST_RESTORE_CHECKLIST.md](../checklists/POST_RESTORE_CHECKLIST.md) |

## 🏗️ What is Patroni?

Patroni is an open-source template for **high-availability PostgreSQL clusters**. It:
- Manages automatic failover when the primary node fails
- Handles leader elections among replicas
- Automatically repairs failed nodes
- Maintains replication streaming between nodes

### Key Components:
```
┌─────────────────────────────────────────────────────┐
│ Patroni HA Cluster (3 Nodes)                        │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────┐  ┌──────────────┐               │
│  │   PRIMARY    │  │   REPLICA 1  │               │
│  │  (Leader)    │  │              │               │
│  └──────────────┘  └──────────────┘               │
│         │  Replication Stream  │                   │
│         └─────────────────────┘                    │
│                                                     │
│  ┌──────────────┐                                  │
│  │   REPLICA 2  │                                  │
│  │              │  (Replication Stream)            │
│  └──────────────┘                                  │
│         ▲                                          │
│         │ Distributed Configuration Store (etcd)   │
│         │ Stores: Cluster state, Leader info       │
│         │ Uses:  Consensus for elections           │
│         └──────────────────────────────────────    │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## 🔄 The Restoration Scenario

**Situation:** Your Patroni cluster has failed and you need to restore it from a backup.

**Solution:** Use pgBackRest (a backup tool) to restore PostgreSQL data files, then let Patroni take over management.

### Why It's Tricky:
- PostgreSQL is running, but Patroni manages it
- Backups include data BUT not the "system identifier"
- Stopping and restarting must happen in specific order
- Permissions must be correct or restore fails

## 9️⃣ The 9-Step Process (Overview)

```
STEP 1: Check Backups
   └─> List available restore points using pgbackrest
   └─> Choose backup timestamp to restore from

STEP 2: Stop Patroni Safely
   └─> Stop on ALL nodes simultaneously
   └─> Prevents "split-brain" scenario

STEP 3: Clean Data Directory
   └─> Rename old /var/lib/postgresql/15/main
   └─> Create fresh empty directory
   └─> pgBackRest will populate it

STEP 4: Run pgBackRest Restore
   └─> Execute: pgbackrest restore --stanza=demo --delta
   └─> Takes 5-10 minutes
   └─> Restores all data files + WAL for recovery

STEP 5: Verify Restored Files
   └─> Check that data directory is populated
   └─> Verify all required PostgreSQL files exist

STEP 6: Fix Permissions
   └─> Change ownership: postgres:postgres
   └─> Set mode: 0700
   └─> PostgreSQL user must own data directory

STEP 7: Start PostgreSQL Manually
   └─> Use: pg_ctl start (manual mode)
   └─> PostgreSQL plays WAL (Write-Ahead Logs) to recover
   └─> Brings database to consistent state
   └─> Takes 3-5 minutes

STEP 8: Hand Control to Patroni
   └─> Stop PostgreSQL
   └─> Start Patroni service
   └─> Patroni becomes cluster manager
   └─> Patroni starts PostgreSQL again

STEP 9: Verify Cluster Health
   └─> Check all 3 nodes are online
   └─> Verify replication is working
   └─> Confirm zero data loss
```

## 🔴 Common Problems & Quick Fixes

| Problem | Error Message | Fix | Time |
|---------|---------------|-----|------|
| **Wrong Owner** | Permission denied | `chown -R postgres:postgres /var/lib/postgresql/15/main` | 30 sec |
| **Case Mismatch** | Stanza mismatch error | Change `[Demo]` to `[demo]` in pgbackrest.conf | 1 min |
| **Stale Metadata** | System ID mismatch | Remove old cluster from etcd, let Patroni re-bootstrap | 2 min |

## 📚 Detailed Documentation Structure

```
Start with one of these paths:

BEGINNER PATH:
  1. Read: docs/OVERVIEW.md (what is this?)
  2. Read: docs/TERMINOLOGY.md (learn the terms)
  3. Study: architecture/CLUSTER_ARCHITECTURE.md (how it works)
  4. Follow: procedures/01_CHECK_BACKUPS.md through 09_VERIFY_CLUSTER.md

EXPERIENCED ADMIN PATH:
  1. Review: failure-analysis/ (learn from mistakes)
  2. Use: checklists/ (verify each step)
  3. Run: scripts/ (automate the process)

TROUBLESHOOTING PATH:
  1. Check: diagrams/FAILURE_DECISION_TREE.md
  2. Read: failure-analysis/FAILURE_MATRIX.md
  3. Search: failure-analysis/ for your specific error
```

## 🛠️ Prerequisites Check

Before you start, verify you have:

- [ ] Ubuntu 22.04 LTS on all 3 nodes
- [ ] PostgreSQL 15 installed: `sudo apt list --installed | grep postgres`
- [ ] Patroni 3.x installed: `patronictl --version`
- [ ] pgBackRest 2.49+: `pgbackrest version`
- [ ] etcd running on all nodes
- [ ] SSH key-based access to all nodes
- [ ] Backup files exist: `pgbackrest info`
- [ ] Sudo access without password prompt
- [ ] At least 20GB free space on data partition

Run the automated check:
```bash
bash scripts/pre_restore_check.sh
```

## ⚡ Quick Checklist

Use these checklists to track your progress:

- **Before Restore:** [checklists/PRE_RESTORE_CHECKLIST.md](../checklists/PRE_RESTORE_CHECKLIST.md)
- **During Restore:** [checklists/DURING_RESTORE_CHECKLIST.md](../checklists/DURING_RESTORE_CHECKLIST.md)
- **After Restore:** [checklists/POST_RESTORE_CHECKLIST.md](../checklists/POST_RESTORE_CHECKLIST.md)
- **Health Check:** [checklists/HEALTH_CHECK_CHECKLIST.md](../checklists/HEALTH_CHECK_CHECKLIST.md)

## 📖 Detailed Step-by-Step

For full details on each step:

1. [Step 1: Check Backups](../procedures/01_CHECK_BACKUPS.md)
2. [Step 2: Stop Patroni](../procedures/02_STOP_PATRONI.md)
3. [Step 3: Clean Data Dir](../procedures/03_CLEAN_DATA_DIR.md)
4. [Step 4: Run Restore](../procedures/04_RUN_RESTORE.md)
5. [Step 5: Verify Files](../procedures/05_VERIFY_FILES.md)
6. [Step 6: Fix Permissions](../procedures/06_FIX_PERMISSIONS.md)
7. [Step 7: Start PostgreSQL](../procedures/07_START_POSTGRESQL.md)
8. [Step 8: Start Patroni](../procedures/08_START_PATRONI.md)
9. [Step 9: Verify Cluster](../procedures/09_VERIFY_CLUSTER.md)

## 🔍 If Something Goes Wrong

**Error? Here's how to find help:**

1. **What's the error message?**
   - Search [failure-analysis/FAILURE_MATRIX.md](../failure-analysis/FAILURE_MATRIX.md)

2. **Not sure what to do?**
   - Follow [diagrams/FAILURE_DECISION_TREE.md](../diagrams/FAILURE_DECISION_TREE.md)

3. **Need specific failure info?**
   - Check [failure-analysis/](../failure-analysis/) for real examples

4. **Want to understand it better?**
   - Read [LESSONS_LEARNED.md](../LESSONS_LEARNED.md)

## ✅ Expected Outcome

After completing all 9 steps, you should have:

- ✅ All 3 nodes online and healthy
- ✅ Primary node elected as leader
- ✅ Both replicas streaming from primary
- ✅ Zero data loss (all transactions recovered)
- ✅ Cluster ready for normal operations

Verification command:
```bash
patronictl list
```

Expected output:
```
+-----------+----------+-----+---------+
| Member    | Host     | Role| Status  |
+-----------+----------+-----+---------+
| primary   | 10.0.1.1 | L   | running |
| replica-1 | 10.0.1.2 | F   | running |
| replica-2 | 10.0.1.3 | F   | running |
+-----------+----------+-----+---------+
```

## 🎓 Next Steps

1. **New User?** → Read [docs/OVERVIEW.md](../docs/OVERVIEW.md)
2. **Ready to start?** → Go to [procedures/01_CHECK_BACKUPS.md](../procedures/01_CHECK_BACKUPS.md)
3. **Need help?** → Check [failure-analysis/FAILURE_MATRIX.md](../failure-analysis/FAILURE_MATRIX.md)
4. **Want to automate?** → Use [scripts/restore_cluster.sh](../scripts/restore_cluster.sh)

---

**Questions?** Explore the [README.md](../README.md) for complete documentation structure.

Good luck with your restore! 🚀
