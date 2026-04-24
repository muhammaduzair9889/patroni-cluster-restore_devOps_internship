# RESTORE_FLOW - Process Flowchart

## 9-Step Restoration Process Flow

```
┌──────────────────────────────────────────────────────────────────────────┐
│              PATRONI CLUSTER RESTORATION PROCESS FLOWCHART               │
└──────────────────────────────────────────────────────────────────────────┘

    ┌─────────────────────────────────────────────────────────────┐
    │  PRE-RESTORE: Run Validation Checklist                      │
    │  - Verify backups exist                                     │
    │  - Check disk space (need > 100GB)                          │
    │  - Verify all nodes accessible                             │
    │  - Check etcd cluster health                               │
    └──────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
    ┌─────────────────────────────────────────────────────────────┐
    │ STEP 1: Check Backups                      (~5 minutes)     │
    │ Command: pgbackrest info                                   │
    │ Verify: Latest backup status = "ok"                        │
    │ Output: Backup date, size, status                          │
    └──────────────────────┬──────────────────────────────────────┘
                           │
                        ✓ Pass?
                          │
        ┌─────────────────┤
        │ ✗ Fail          │ ✓ Pass
        ▼                 ▼
    ❌ STOP           ┌─────────────────────────────────────────────┐
       Backups       │ STEP 2: Stop Patroni              (~5 min)   │
       not found     │ - Stop Patroni on primary                    │
       Check logs    │ - Stop Patroni on replica-1                  │
                     │ - Stop Patroni on replica-2                  │
                     │ - Verify etcd still running                  │
                     └──────────────────┬──────────────────────────┘
                                        │
                                     ✓ Pass?
                                        │
                        ┌───────────────┤
                        │ ✗ Fail        │ ✓ Pass
                        ▼               ▼
                    ❌ STOP         ┌────────────────────────────────┐
                       Patroni     │ STEP 3: Clean Data Dir (~10 min)│
                       not         │ - Backup old data dir           │
                       stopped     │ - Create empty directory        │
                       Try again   │ - Fix ownership: postgres       │
                                   │ - Fix permissions: 0700         │
                                   │ - Verify empty                  │
                                   └──────────────┬───────────────────┘
                                                  │
                                               ✓ Pass?
                                                  │
                                  ┌───────────────┤
                                  │ ✗ Fail        │ ✓ Pass
                                  ▼               ▼
                              ❌ STOP         ┌──────────────────────────┐
                                 Disk        │ STEP 4: Run Restore      │
                                 full        │ (~15-30 minutes)         │
                                 Clean up    │ Command:                 │
                                 old dir     │ pgbackrest restore       │
                                             │ --delta                  │
                                             │ Monitor: tail -f logs    │
                                             └──────────┬───────────────┘
                                                        │
                            ┌───────────────────────────┤
                            │ ✗ Fail                    │ ✓ Pass
                            ▼                           ▼
                        ❌ STOP              ┌─────────────────────────┐
                        Restore             │ STEP 5: Verify Files    │
                        failed              │ (~5 minutes)            │
                        Check logs          │ - Data dir has files    │
                        at failure-         │ - pg_control exists     │
                        analysis/           │ - Size looks correct    │
                                            │ - base/ exists          │
                                            │ - global/ exists        │
                                            │ - pg_wal/ exists        │
                                            └──────────┬──────────────┘
                                                       │
                                                    ✓ Pass?
                                                       │
                                   ┌───────────────────┤
                                   │ ✗ Fail            │ ✓ Pass
                                   ▼                   ▼
                               ❌ STOP            ┌──────────────────────┐
                                  Re-run         │ STEP 6: Fix          │
                                  restore        │ Permissions (~5 min) │
                                  in Step 4      │ - chown postgres     │
                                                 │ - chmod 0700 dirs    │
                                                 │ - chmod 0600 files   │
                                                 │ - Verify fixed       │
                                                 └──────────┬───────────┘
                                                            │
                                                         ✓ Pass?
                                                            │
                                          ┌────────────────┤
                                          │ ✗ Fail         │ ✓ Pass
                                          ▼                ▼
                                      ❌ STOP        ┌─────────────────────┐
                                      Try again      │ STEP 7: Start       │
                                                     │ PostgreSQL          │
                                                     │ (~10-20 min)        │
                                                     │ - Clear shared mem  │
                                                     │ - Start postgres -F │
                                                     │ - Wait for "ready"  │
                                                     │ - Monitor WAL       │
                                                     │ - Background it     │
                                                     │ - Start as service  │
                                                     └──────────┬──────────┘
                                                                │
                                                             ✓ Pass?
                                                                │
                                            ┌───────────────────┤
                                            │ ✗ Fail            │ ✓ Pass
                                            ▼                   ▼
                                        ❌ STOP          ┌────────────────┐
                                        Check logs       │ STEP 8: Start  │
                                        for errors       │ Patroni        │
                                                         │ (~5 minutes)   │
                                                         │ - Start on     │
                                                         │   primary      │
                                                         │ - Wait for     │
                                                         │   election     │
                                                         │ - Start on     │
                                                         │   replicas     │
                                                         │ - Verify all   │
                                                         │   online       │
                                                         └────────┬───────┘
                                                                  │
                                                               ✓ Pass?
                                                                  │
                                                  ┌───────────────┤
                                                  │ ✗ Fail        │ ✓ Pass
                                                  ▼               ▼
                                              ❌ STOP         ┌────────────────┐
                                              Check etcd,     │ STEP 9: Verify │
                                              system ID       │ Cluster        │
                                              (see             │ (~10 min)      │
                                              failure-        │ - List cluster │
                                              analysis/)      │ - Check repl   │
                                                              │ - Verify data  │
                                                              │ - No errors    │
                                                              │ - Test write   │
                                                              └────────┬───────┘
                                                                       │
                                                                    ✓ Pass?
                                                                       │
                                                       ┌───────────────┤
                                                       │ ✗ Fail        │ ✓ Pass
                                                       ▼               ▼
                                                   ❌ FAILED      ✅ SUCCESS
                                                   Restore        Cluster
                                                   investigate    restored
                                                   issues
```


## Parallel Operations Possible

```
Some operations can run in parallel on different nodes:

┌─ Step 2: Stop Patroni
│  ├─ Stop primary (node-1)
│  ├─ Stop replica-1 (node-2)  ◄─ Can run in parallel
│  └─ Stop replica-2 (node-3)

┌─ Step 8: Start Patroni
│  ├─ Start primary (node-1)
│  ├─ Wait for election (30 sec)
│  ├─ Start replica-1 (node-2)  ◄─ Can run in parallel
│  └─ Start replica-2 (node-3)

But Steps 1-7 must run sequentially (restore only on primary)
```


## Expected Timings

```
Total Restore Time: 45 - 90 minutes

Step    Name                        Time      Why
────────────────────────────────────────────────────────────────
1       Check Backups               5 min     Quick verification
2       Stop Patroni                5 min     Clean shutdown
3       Clean Data Dir              10 min    IO dependent
4       Run Restore                 15-30 min ◄─ LONGEST (depends on DB size)
5       Verify Files                5 min     Quick checks
6       Fix Permissions             5 min     IO dependent
7       Start PostgreSQL            10-20 min ◄─ WAL recovery time (depends on load)
8       Start Patroni               5 min     Election + cluster formation
9       Verify Cluster              10 min    Final validation
────────────────────────────────────────────────────────────────
TOTAL                               75-90 min

Critical Path (longest): Step 4 + Step 7 = 25-50 minutes
```


## Exit Points (Rollback)

If restore fails at any step:

1. **Before Step 4 (before restore):**
   - Can restore old data directory: `mv /var/lib/postgresql/15/main.backup /var/lib/postgresql/15/main`
   - Start PostgreSQL normally
   - Cluster returns to last known good state

2. **After Step 4 (after restore):**
   - More complex to rollback
   - Have backup-of-backup available
   - May need to redo entire restore
   - Document how to proceed

3. **After Step 8 (Patroni running):**
   - If issues, can scale down cluster
   - Start manual PostgreSQL on one node
   - Sync other nodes from that node
   - Or restore again from fresh backup


## Decision Tree for Failures

See [FAILURE_DECISION_TREE.md](FAILURE_DECISION_TREE.md) for detailed troubleshooting at each step.


## Related Documentation

- [../procedures/](../procedures/) - Detailed step-by-step procedures
- [../failure-analysis/](../failure-analysis/) - Common failures and fixes
- [../checklists/DURING_RESTORE_CHECKLIST.md](../checklists/DURING_RESTORE_CHECKLIST.md) - Checklist version
- [CLUSTER_TOPOLOGY.md](CLUSTER_TOPOLOGY.md) - System architecture
