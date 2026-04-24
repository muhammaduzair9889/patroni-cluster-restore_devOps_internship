# Step-by-Step Restoration Procedures

This section contains the complete 9-step restoration process with detailed commands and explanations.

## Overview

The restoration process takes approximately **20-30 minutes** and consists of these steps:

| Step | Name | Purpose | Time | Difficulty |
|------|------|---------|------|------------|
| 1 | Check Backups | Verify backup exists | 2 min | Easy |
| 2 | Stop Patroni | Prevent cluster conflicts | 1 min | Easy |
| 3 | Clean Data Dir | Prepare for restore | 2 min | Easy |
| 4 | Run Restore | Copy backup to server | 5-10 min | Medium |
| 5 | Verify Files | Check restoration success | 2 min | Easy |
| 6 | Fix Permissions | Ensure correct ownership | 1 min | Easy |
| 7 | Start PostgreSQL | Complete WAL recovery | 3-5 min | Medium |
| 8 | Start Patroni | Resume cluster management | 1 min | Easy |
| 9 | Verify Cluster | Confirm all nodes healthy | 3 min | Easy |

## Critical Prerequisites

Before starting any procedure, verify:

- [ ] All 3 nodes are accessible via SSH
- [ ] SSH key-based authentication works
- [ ] You have sudo access on all nodes
- [ ] Backup repository is accessible
- [ ] At least 100GB free disk space
- [ ] etcd cluster is running on all nodes
- [ ] All nodes have identical PostgreSQL version (15)
- [ ] All nodes have identical Patroni version (3.x)

## Files in This Directory

### 01_CHECK_BACKUPS.md
Step 1 detailed procedure - List and verify available backups

### 02_STOP_PATRONI.md
Step 2 detailed procedure - Stop Patroni safely on all nodes

### 03_CLEAN_DATA_DIR.md
Step 3 detailed procedure - Clean and prepare data directory

### 04_RUN_RESTORE.md
Step 4 detailed procedure - Execute pgBackRest restore

### 05_VERIFY_FILES.md
Step 5 detailed procedure - Verify restored files

### 06_FIX_PERMISSIONS.md
Step 6 detailed procedure - Fix file ownership and permissions

### 07_START_POSTGRESQL.md
Step 7 detailed procedure - Start PostgreSQL and complete WAL recovery

### 08_START_PATRONI.md
Step 8 detailed procedure - Start Patroni and resume cluster management

### 09_VERIFY_CLUSTER.md
Step 9 detailed procedure - Verify complete cluster health

## Quick Command Reference

See [../docs/QUICK_START.md](../docs/QUICK_START.md) for fast reference of all commands.

## Troubleshooting Each Step

If you encounter errors:
1. Check [../failure-analysis/](../failure-analysis/) for your specific error
2. Review [../LESSONS_LEARNED.md](../LESSONS_LEARNED.md) for insights
3. Use [../diagrams/FAILURE_DECISION_TREE.md](../diagrams/FAILURE_DECISION_TREE.md) for diagnosis

## How to Use This Section

1. **First time?** Read each procedure completely before executing
2. **Have experience?** Use the quick commands with caution
3. **Troubleshooting?** Use alongside failure analysis docs
4. **Automating?** See [../scripts/restore_cluster.sh](../scripts/restore_cluster.sh)

## Important Notes

- ⚠️ **Stop Patroni on ALL nodes before restoring** - Prevents split-brain
- ⚠️ **Run restore on PRIMARY node only** - Not on replicas
- ⚠️ **Check backups before starting** - Ensure restore point exists
- ⚠️ **Have recent backups** - Don't rely on month-old backups
- ⚠️ **Test in sandbox first** - Always validate procedures

---

**Ready?** Start with [01_CHECK_BACKUPS.md](01_CHECK_BACKUPS.md)
