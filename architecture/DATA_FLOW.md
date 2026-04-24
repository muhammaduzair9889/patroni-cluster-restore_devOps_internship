# Data Flow - How Data Moves Through the System

## Data Flow During Normal Operations

### Write Transaction Flow

```
Step 1: Client sends INSERT/UPDATE/DELETE
┌──────────────┐
│ Application  │
│ Client       │
└──────┬───────┘
       │ SQL Query (INSERT INTO table VALUES...)
       │ via TCP 5432
       ▼
┌─────────────────────────────────────┐
│ PostgreSQL Primary (Primary Node)    │
├─────────────────────────────────────┤
│ 1. Parse & validate query           │
│ 2. Start transaction                │
│ 3. Modify buffers in memory         │
│ 4. Generate WAL entry               │
│ 5. Write WAL entry to disk          │
│    └─ /var/lib/postgresql/15/..     │
│ 6. Flush WAL entry                  │
│    ├─ To Local Disk (safety)        │
│    └─ To Replication Stream         │
│ 7. Commit transaction               │
│ 8. Return ACK to client             │
└──────┬───────────────────────────────┘
       │
       │ asynchronous (fire-and-forget)
       │ or
       │ synchronous (wait for ACK)
       │
       ├─────────────────────────────────────────┐
       │                                         │
       ▼                                         ▼
┌──────────────────────────┐           ┌────────────────────────────────┐
│ Replica Node 1           │           │ Replica Node 2                 │
├──────────────────────────┤           ├────────────────────────────────┤
│ 1. Receive WAL entry     │           │ 1. Receive WAL entry           │
│ 2. Write to local WAL    │           │ 2. Write to local WAL          │
│ 3. Acknowledge receipt   │           │ 3. Acknowledge receipt         │
│ 4. Apply change to table │           │ 4. Apply change to table       │
│ 5. Update LSN position   │           │ 5. Update LSN position         │
└──────────────────────────┘           └────────────────────────────────┘
       │                                         │
       │ Synchronous replication: Primary       │
       │ waits for ACK from at least one        │
       │ replica before confirming to client    │
       └─────────────────────────────────────────┘
                    │
                    ▼
            ┌────────────────────┐
            │ Transaction safely  │
            │ committed on at     │
            │ least 2 nodes       │
            │ (zero data loss)    │
            └────────────────────┘
```

### Read Transaction Flow

```
Client sends SELECT
       │
       ▼
┌─────────────────────────────┐         ┌─────────────────────────────┐
│ Primary (accepts reads)      │         │ Replica (read-only)         │
│ /var/lib/postgresql/15/main/ │ ◄────► │ /var/lib/postgresql/15/main/│
│ ├─ Read latest data         │   OR    │ ├─ Read replicated data     │
│ ├─ Indexes up-to-date       │         │ ├─ Slightly behind (lag)    │
│ └─ Return result            │         │ └─ Return result            │
└─────────────────────────────┘         └─────────────────────────────┘

Typical setup:
├─ Application writes to Primary (5432)
├─ Application reads from Replicas (5432)
└─ Load-balanced read queries across replicas
```

## Data Flow During Backup Creation

### Full Backup Flow

```
pgBackRest Starts Full Backup
       │
       ▼
Connect to PostgreSQL
       │
       ├─ Request backup start (pg_start_backup)
       │  └─ PostgreSQL creates backup label
       │  └─ PostgreSQL records LSN position
       │
       ▼
┌────────────────────────────────────┐
│ PostgreSQL Data Directory           │
│ /var/lib/postgresql/15/main/        │
├────────────────────────────────────┤
│ base/                               │
│ ├─ 1/                               │
│ │  ├─ 16385  (table file)          │
│ │  ├─ 16386  (table file)          │
│ │  └─ ...                           │
│ ├─ 16385/                          │
│ │  ├─ 16389  (table file)          │
│ │  └─ ...                           │
│ global/                             │
│ pg_wal/ (active WAL files)          │
│ └─ ...                              │
└────────────┬───────────────────────┘
             │ pgBackRest reads in parallel
             │ (16 threads typical)
             │
             ▼
    ┌────────────────────┐
    │ Copy all files     │
    │ - Table data       │
    │ - Indexes          │
    │ - Config files     │
    │ - Other files      │
    └────────┬───────────┘
             │
             ▼
    ┌────────────────────┐
    │ Compress data      │
    │ (zstd or pgz)      │
    │ Reduces size ~10x  │
    └────────┬───────────┘
             │
             ▼
    ┌────────────────────┐
    │ Copy WAL files     │
    │ From start to end  │
    │ of backup          │
    └────────┬───────────┘
             │
             ▼
    ┌────────────────────┐
    │ Request backup end │
    │ (pg_stop_backup)   │
    │ PostgreSQL creates │
    │ backup label       │
    └────────┬───────────┘
             │
             ▼
    ┌────────────────────┐
    │ Verify backup      │
    │ - Check sums       │
    │ - File counts      │
    │ - Integrity        │
    └────────┬───────────┘
             │
             ▼
    ┌────────────────────┐
    │ Update backup.info │
    │ - Backup type: F   │
    │ - Start LSN        │
    │ - End LSN          │
    │ - Database version │
    │ - System ID        │
    └────────┬───────────┘
             │
             ▼
┌──────────────────────────────────────┐
│ Backup Repository                    │
│ /mnt/pgbackrest-repo/demo/backup/    │
├──────────────────────────────────────┤
│ 20260410-164501F/                    │
│ ├─ backup.info        (metadata)     │
│ ├─ base/              (compressed)   │
│ │  ├─ backup files...                │
│ │  └─ ...                            │
│ ├─ global/            (compressed)   │
│ │  └─ backup files...                │
│ └─ ...                               │
│                                      │
│ Size: ~50GB (compressed from 500GB)  │
└──────────────────────────────────────┘
```

### Differential Backup Flow

```
pgBackRest Starts Differential Backup
       │
       ├─ Read last full backup metadata
       │  └─ Learn which files were in full backup
       │
       ▼
┌──────────────────────────────────────┐
│ PostgreSQL Data Directory            │
│ Compare: Current vs Last Full Backup │
├──────────────────────────────────────┤
│ Changed Files:                       │
│ ├─ base/16385/16389  (modified)     │
│ ├─ base/16385/16390  (new)          │
│ └─ pg_wal/...        (all WAL)      │
│                                      │
│ Unchanged Files:                     │
│ ├─ base/1/...        (skip - no dif)│
│ └─ global/...        (skip - no dif)│
└────────┬─────────────────────────────┘
         │ Only copy changed files
         │
         ▼
┌──────────────────────────────────────┐
│ Backup Repository                    │
│ /mnt/pgbackrest-repo/demo/backup/    │
├──────────────────────────────────────┤
│ 20260410-164501F/    (full backup)   │
│                                      │
│ 20260412-164510D/    (differential)  │
│ ├─ backup.info       (metadata)      │
│ ├─ Changed files     (only deltas)   │
│ └─ WAL files         (recovery)      │
│                                      │
│ Size: ~30GB (only changes)           │
└──────────────────────────────────────┘

Time Saved: Only copy 30% of data
Recovery: Requires full backup + differential backup
```

### Incremental Backup Flow

```
pgBackRest Starts Incremental Backup
       │
       ├─ Read last backup metadata
       │  └─ Only compare to LAST backup (full or diff)
       │
       ▼
┌──────────────────────────────────────┐
│ PostgreSQL Data Directory            │
│ Compare: Current vs Last Backup      │
├──────────────────────────────────────┤
│ Changed Files (Since Last Backup):   │
│ ├─ base/16385/16390  (modified)     │
│ └─ pg_wal/...        (all WAL)      │
│                                      │
│ Unchanged Files:                     │
│ ├─ Everything else... (skip)        │
└────────┬─────────────────────────────┘
         │ Only copy newly changed files
         │
         ▼
┌──────────────────────────────────────┐
│ Backup Repository                    │
│ /mnt/pgbackrest-repo/demo/backup/    │
├──────────────────────────────────────┤
│ 20260410-164501F/    (full)          │
│ 20260412-164510D/    (differential)  │
│ 20260414-164520I/    (incremental)   │
│                                      │
│ 20260414-164520I/                    │
│ ├─ backup.info       (metadata)      │
│ ├─ Changed files     (only latest)   │
│ └─ WAL files         (recovery)      │
│                                      │
│ Size: ~5GB (only recent changes)     │
└──────────────────────────────────────┘

Time Saved: Only copy 1% of data
Recovery: Requires full + differential + incremental
Strategy: (Full weekly, Diff daily, Incr hourly)
```

## Data Flow During WAL Archiving

### Continuous WAL Stream

```
PostgreSQL generates WAL files
       │
       ├─ One WAL file = 16MB
       ├─ Generated continuously during activity
       └─ Stored in /var/lib/postgresql/15/main/pg_wal/
                │
                │ File: 000000010000000000000001
                │       000000010000000000000002
                │       000000010000000000000003
                │       (increasing sequence)
                │
                ▼
    ┌──────────────────────────┐
    │ PostgreSQL archive_command│
    │ Triggered for each WAL    │
    │ file when checkpoint      │
    │ completes                 │
    └────────┬─────────────────┘
             │
             ▼
    ┌──────────────────────────┐
    │ pgBackRest archive-push   │
    │ - Copy WAL to repository  │
    │ - Compress WAL            │
    │ - Verify archive success  │
    └────────┬─────────────────┘
             │
             ▼
┌──────────────────────────────────────┐
│ Backup Repository                    │
│ /mnt/pgbackrest-repo/demo/wal/       │
├──────────────────────────────────────┤
│ 00000001/                            │
│ ├─ 000000010000000000000001.gz       │
│ ├─ 000000010000000000000002.gz       │
│ ├─ 000000010000000000000003.gz       │
│ └─ ... (thousands of WAL files)      │
│                                      │
│ Retention: 30 days                   │
│ Size: WAL files accumulate 50GB      │
└──────────────────────────────────────┘
```

## Data Flow During Restore

### Point-in-Time Recovery

```
Backup Repository Contains:
├─ Full Backup (2026-04-10, LSN 1/00000000)
├─ Differential Backup (2026-04-12, LSN 1/20000000)
└─ WAL Files (April 10 - April 14)
   └─ Continuous archive of transactions

User chooses: Restore to 2026-04-14 12:00:00 (specific point-in-time)
       │
       ▼
┌────────────────────────────────────────────┐
│ pgBackRest Restore Decision                │
├────────────────────────────────────────────┤
│ 1. Find backup that covers target time    │
│    └─ Full backup (Apr 10) is earlier    │
│    └─ Differential (Apr 12) is earlier   │
│    └─ Both can be used                   │
│                                           │
│ 2. Optimal restore plan:                 │
│    ├─ Use Differential (newer, faster)  │
│    ├─ Get WAL files from Apr 12 → Apr 14│
│    └─ Will restore to Apr 14 12:00:00   │
└────────┬───────────────────────────────────┘
         │
         ▼
    ┌────────────────────────┐
    │ Copy Differential      │
    │ Backup Data to Server  │
    │                        │
    │ /var/lib/postgresql/.. │
    │ Populates:             │
    │ ├─ base/               │
    │ ├─ global/             │
    │ └─ All data files      │
    │                        │
    │ Time: 5 minutes        │
    └────────┬───────────────┘
             │
             ▼
    ┌────────────────────────────────────┐
    │ Copy WAL files from Apr 12 → Apr 14│
    │                                    │
    │ WAL Files:                         │
    │ └─ 000000010000000000000050.gz     │
    │ └─ 000000010000000000000051.gz     │
    │ └─ ... (many WAL files)            │
    │                                    │
    │ To: /var/lib/postgresql/15/main/.. │
    │                                    │
    │ Time: 2 minutes                    │
    └────────┬───────────────────────────┘
             │
             ▼
    ┌────────────────────────────────────┐
    │ Fix Permissions                    │
    │                                    │
    │ chown postgres:postgres ...        │
    │ chmod 0700 ...                     │
    └────────┬───────────────────────────┘
             │
             ▼
    ┌────────────────────────────────────┐
    │ PostgreSQL Starts (Manual Mode)    │
    │                                    │
    │ 1. Read pg_control file           │
    │    └─ Understand cluster state    │
    │                                    │
    │ 2. Find WAL to replay             │
    │    └─ Scan pg_wal/ directory      │
    │                                    │
    │ 3. Replay WAL files               │
    │    ├─ Execute each transaction    │
    │    ├─ Build data pages            │
    │    └─ Reach point-in-time         │
    │       (Apr 14 12:00:00)            │
    │                                    │
    │ 4. Reach consistency              │
    │    └─ All transactions applied    │
    │                                    │
    │ Time: 5 minutes                   │
    └────────┬───────────────────────────┘
             │
             ▼
    ┌────────────────────────────────────┐
    │ Database Recovered at:             │
    │ 2026-04-14 12:00:00                │
    │                                    │
    │ All changes before this time: ✓   │
    │ All changes after this time: ✗    │
    │ (Lost forever per restore choice)  │
    └────────────────────────────────────┘
```

## Data Flow During Failover

### Automatic Failover Scenario

```
Time T=0:00 - Normal Operation
┌─────────────────────────────┐
│ Primary (Leader)            │
│ Accepting reads/writes      │
│ Streaming WAL to replicas   │
└─────────────────────────────┘

Time T=0:05 - Primary Fails
┌─────────────────────────────┐
│ Primary ❌ CRASHES           │
│ Network down / Hardware fail│
└─────────────────────────────┘
         │
         │ 5 seconds pass
         │ (Patroni health check timeout)
         │
         ▼
Time T=0:10 - Patroni Detects Failure
┌─────────────────────────────┐
│ Replica-1 Patroni           │
│ Health check fails (timeout)│
│ Sends: PRIMARY_DOWN alert   │
│ to etcd                     │
└─────────────────────────────┘

         │
         ▼
Time T=0:11 - Leader Election
┌─────────────────────────────────────────┐
│ etcd (Distributed Consensus)            │
│                                         │
│ Quorum vote: Which replica becomes     │
│ new primary?                            │
│                                         │
│ Candidates:                             │
│ ├─ Replica-1 (priority 100, LSN: X)   │
│ └─ Replica-2 (priority 100, LSN: X)   │
│                                         │
│ Voting criteria:                        │
│ 1. Highest priority                     │
│ 2. Most recent data (highest LSN)       │
│ 3. Random tiebreak                      │
│                                         │
│ Winner: Replica-1                       │
└─────────────────────────────────────────┘
         │
         ▼
Time T=0:12 - Promotion
┌──────────────────────────────────────┐
│ Replica-1 Patroni                    │
│                                      │
│ 1. Read election result from etcd   │
│    └─ "I won, become primary!"      │
│                                      │
│ 2. Stop replication (no longer      │
│    replica)                          │
│                                      │
│ 3. Promote PostgreSQL                │
│    └─ pg_ctl promote command         │
│    └─ Finalize recovery              │
│    └─ Accept writes now              │
│                                      │
│ 4. Update etcd:                      │
│    └─ New leader = replica-1        │
└──────────────────────────────────────┘
         │
         ▼
Time T=0:13 - Replica-2 Reconnects
┌──────────────────────────────────────┐
│ Replica-2 Patroni                    │
│                                      │
│ 1. Detect: Primary now replica-1    │
│                                      │
│ 2. Connect to new primary            │
│    └─ TCP connection established     │
│                                      │
│ 3. Start replication stream          │
│    └─ Read WAL from new primary      │
│    └─ Apply changes locally          │
│                                      │
│ 4. Data sync begins                  │
│    └─ Catch up to replica-1          │
└──────────────────────────────────────┘
         │
         ▼
Time T=0:15 - New Cluster Operational
┌────────────────────────────────┐
│ New Primary (replica-1)         │
│ ├─ Accepting reads/writes       │
│ └─ Streaming WAL                │
│                                 │
│ New Replica-2                   │
│ ├─ Connected                    │
│ ├─ Applying changes             │
│ └─ Data syncing...              │
│                                 │
│ Old Primary ❌                   │
│ ├─ Still offline                │
│ └─ Needs manual recovery        │
└────────────────────────────────┘

RESULT:
├─ Downtime: ~15 seconds
├─ Data Loss: 0 bytes (sync replication)
├─ Applications reconnect: Automatic
└─ Cluster continues: ✓
```

---

**Summary:** Understanding data flow helps you:
1. Predict where data is at any moment
2. Understand failure scenarios
3. Plan for capacity and performance
4. Design backup strategies
5. Debug replication issues

