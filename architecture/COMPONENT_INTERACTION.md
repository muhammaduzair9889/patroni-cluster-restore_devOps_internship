# Component Interaction - How Patroni, PostgreSQL, and pgBackRest Work Together

## System Components Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                   COMPONENT INTERACTION                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐                                              │
│  │ PostgreSQL   │ ◄────────────────┐                           │
│  │ Database     │                  │                           │
│  │ (Data Store) │                  │ Manages                   │
│  └──────┬───────┘                  │                           │
│         │ Runs/Controlled by      │                           │
│         │                          │                           │
│  ┌──────▼──────────────────────────┴────────────┐             │
│  │            PATRONI               (Manager)    │             │
│  │  - Start/stop PostgreSQL                    │             │
│  │  - Monitor health                           │             │
│  │  - Handle replication                       │             │
│  │  - Coordinate failover                      │             │
│  └──────┬──────────────────────────┬───────────┘             │
│         │                          │                          │
│         │ Reads/Writes            │ Communicates             │
│         │                          │                          │
│  ┌──────▼──────────────┐  ┌───────▼────────────────┐        │
│  │   PostgreSQL Data   │  │   Distributed Config   │        │
│  │   Directory         │  │   Store (etcd)         │        │
│  │                     │  │                        │        │
│  │ /var/lib/..         │  │ - Cluster state        │        │
│  │ ├─ base/            │  │ - Leader info          │        │
│  │ ├─ pg_wal/          │  │ - Member status        │        │
│  │ └─ config files     │  │ - Configuration        │        │
│  └─────────────────────┘  └────────────────────────┘        │
│                                     ▲                         │
│                                     │                         │
│                          Read cluster state                   │
│                                     │                         │
│  ┌────────────────────────────────────────────────┐          │
│  │         pgBackRest (Backup Tool)               │          │
│  │  - Create backups                            │          │
│  │  - Archive WAL files                         │          │
│  │  - Restore from backups                      │          │
│  └────────────────┬─────────────────────────────┘          │
│                   │ Reads/Writes                           │
│                   │                                        │
│  ┌────────────────▼──────────────────────────────┐         │
│  │    Backup Repository                         │         │
│  │    /mnt/pgbackrest-repo/                    │         │
│  │    ├─ Backups                               │         │
│  │    │  ├─ Full                               │         │
│  │    │  ├─ Differential                       │         │
│  │    │  └─ Incremental                        │         │
│  │    └─ WAL Archives                          │         │
│  └─────────────────────────────────────────────┘         │
│                                                           │
└─────────────────────────────────────────────────────────────┘
```

## Component Roles & Responsibilities

### PostgreSQL Database

**Role:** Data storage and management

**Responsibilities:**
- Store all database data (tables, indexes, etc.)
- Execute queries from clients
- Maintain transaction consistency
- Generate write-ahead logs (WAL)
- Manage replication as standby

**Communication:**
- **Receives commands from:** Patroni (start, stop, restart)
- **Provides status to:** Patroni (health check)
- **Streams data to:** Replica PostgreSQL instances
- **Writes logs to:** WAL directory, pgBackRest archives

**Critical Files:**
```
/var/lib/postgresql/15/main/
├── base/                  # Table data files
├── pg_wal/               # Active transaction logs
├── pg_control            # Cluster metadata
├── postgresql.conf       # Configuration
└── PG_VERSION           # Version info
```

### Patroni (HA Manager)

**Role:** Orchestration and cluster management

**Responsibilities:**
- **Start/Stop PostgreSQL** - Control PostgreSQL lifecycle
- **Monitor Health** - Check if PostgreSQL is responsive
- **Manage Replication** - Configure standby connections
- **Handle Failover** - Promote replica if primary fails
- **Coordinate Elections** - Elect new leader via etcd
- **Apply Configuration** - Manage postgresql.conf
- **API Endpoint** - Provide health/cluster info to tools

**Communication:**
- **Controls:** PostgreSQL daemon (pg_ctl commands)
- **Reads/Writes to:** etcd (cluster state, leader election)
- **Provides API to:** patronictl tool
- **Coordinates with:** Other Patroni nodes

**Key Functions:**
```
Patroni Process
├── PostgreSQL Monitor
│   ├── Is PG running?
│   ├── Can connect?
│   └─ Health OK?
├── DCS Client (etcd)
│   ├── Register node
│   ├─ Announce health
│   └─ Learn leader
├── Election Manager
│   ├─ Participate in election
│   ├─ Become primary if elected
│   └─ Follow primary if not
└── Replica Manager
    ├─ Connect to primary
    ├─ Stream replication
    └─ Maintain copy
```

### etcd (Distributed Configuration Store)

**Role:** Cluster state management and coordination

**Responsibilities:**
- **Store Cluster State** - Who is primary, who are replicas
- **Maintain Consensus** - Multiple nodes agree on state
- **Leader Election** - Determine which replica becomes primary
- **Prevent Split-Brain** - Ensure only one primary exists
- **Configuration Storage** - Shared cluster parameters

**Communication:**
- **Receives from:** Patroni on all 3 nodes
- **Provides to:** Patroni on all 3 nodes
- **Protocol:** RAFT consensus for reliability

**Key Data:**
```
/patroni/demo/
├── leader                      # Name of current primary
├── initialize                  # Cluster initialized flag
├── members/
│   ├── primary                # Primary node status
│   ├── replica-1              # Replica-1 status
│   └── replica-2              # Replica-2 status
└── config                      # Shared configuration
```

### pgBackRest (Backup Tool)

**Role:** Backup creation and restoration

**Responsibilities:**
- **Create Backups** - Full, differential, incremental
- **Archive WAL Files** - Continuous backup of transaction logs
- **Compress Data** - Reduce backup size
- **Encrypt Backups** - Security
- **Validate Backups** - Verify integrity
- **Restore from Backup** - Copy data back to server
- **Manage Retention** - Delete old backups

**Communication:**
- **Reads from:** PostgreSQL data directory
- **Writes to:** Backup repository
- **Uses:** WAL streaming for continuous archiving
- **Provides:** Backup info via `pgbackrest info`

**Key Commands:**
```
pgBackRest
├── Backup Operations
│   ├── pgbackrest backup          # Create backup
│   └─ pgbackrest info            # List backups
├── Restore Operations
│   ├─ pgbackrest restore         # Full restore
│   └─ pgbackrest restore --delta # Delta restore
└─ WAL Archive
    └─ pgbackrest archive-push    # Continuous WAL backup
```

### Backup Repository

**Role:** Persistent storage of backups

**Responsibilities:**
- **Store Backup Data** - Full, differential, incremental backups
- **Store WAL Files** - Transaction logs for recovery
- **Support Compression** - pgBackRest-compressed format
- **Maintain Permissions** - postgres user ownership
- **Provide Capacity** - Sufficient disk space

**Location:** `/mnt/pgbackrest-repo/` (NFS or local)

**Contents:**
```
/mnt/pgbackrest-repo/demo/
├── backup/
│   ├── 20260410-164501F/        # Full backup
│   ├── 20260412-164510D/        # Differential
│   └── 20260414-164520I/        # Incremental
└── wal/
    ├── 00000001/                # WAL files (thousands)
    └── ...
```

## Interaction Flows

### Normal Operation (Replication & HA)

```
Time: T0
┌─────────────────────────────────────────┐
│ Primary Node                            │
├─────────────────────────────────────────┤
│ PostgreSQL receives INSERT from client  │
│ ├─ Write data to table                 │
│ ├─ Write WAL entry                     │
│ └─ Return ACK to client                │
└─────────────────────────────────────────┘
                  │
                  │ WAL Streaming
                  ▼
┌─────────────────────────────────────────┐
│ Replica Node 1                          │
├─────────────────────────────────────────┤
│ Receives WAL from Primary               │
│ ├─ Write to local WAL directory         │
│ ├─ Apply changes to table               │
│ └─ Update replication position          │
└─────────────────────────────────────────┘

Patroni on Primary:
├─ Monitors PostgreSQL health (OK)
└─ Reads etcd: "I am leader" ✓

Patroni on Replica:
├─ Monitors PostgreSQL health (OK)
├─ Maintains replication connection
└─ Reads etcd: "Primary is the leader" ✓

etcd:
├─ Stores: Leader = primary
├─ Stores: Member status = all running
└─ Stores: Replication working
```

### Backup Creation Flow

```
pgBackRest Backup Schedule (Weekly)
        │
        ▼
┌──────────────────────────────┐
│ pgBackRest Backup Process    │
├──────────────────────────────┤
│ 1. Connect to PostgreSQL     │
│ 2. Request backup label      │
│ 3. Copy data files (parallel)│
│ 4. Copy WAL files            │
│ 5. Compress all files        │
│ 6. Verify checksum           │
│ 7. Update backup.info        │
└──────────────────────────────┘
        │
        ▼
┌──────────────────────────────┐
│ Backup Repository            │
│ /mnt/pgbackrest-repo/demo/   │
│                              │
│ Before: 250GB (older backups)│
│ After:  300GB (new backup)   │
│         +50GB backup created │
└──────────────────────────────┘
```

### Continuous WAL Archiving

```
PostgreSQL WAL Generation
        │ (Every few MB or seconds)
        ▼
WAL File Created (16MB)
        │ 000000010000000000000037
        ▼
pgBackRest Continuous Archive
        │ (Triggered by archive_command)
        ▼
Copy WAL to Repository
        │ /mnt/pgbackrest-repo/demo/wal/
        └─ 000000010000000000000037
                │
                ▼
        Archive Complete
        │ (Ready for recovery)
        ▼
Keep for 30 days
        │ (Per retention policy)
        ▼
Delete when expired
```

### Restore Flow (During Recovery)

```
Cluster fails → Restore initiated
        │
        ▼
┌──────────────────────────────────┐
│ Step 1: Stop Patroni             │
├──────────────────────────────────┤
│ - All nodes: systemctl stop patroni
│ - PostgreSQL still running?
│ - If yes: systemctl stop postgres
└──────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────┐
│ Step 2: Clean Data Directory     │
├──────────────────────────────────┤
│ - Rename /var/lib/postgresql...
│ - Create fresh directory
│ - Set ownership to postgres:postgres
└──────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────┐
│ Step 3: pgBackRest Restore       │
├──────────────────────────────────┤
│ - Read: Backup Repository        │
│ - Copy: Backup data              │
│ - Copy: WAL files for recovery   │
│ - Write: /var/lib/postgresql..   │
│ - Decompress files               │
│ - Time: 5-10 minutes             │
└──────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────┐
│ Step 4: Fix Permissions          │
├──────────────────────────────────┤
│ - chown postgres:postgres ...     │
│ - chmod 0700 ...                 │
└──────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────┐
│ Step 5: PostgreSQL WAL Recovery  │
├──────────────────────────────────┤
│ - Start PostgreSQL manually       │
│ - Read pg_control               │
│ - Replay WAL files              │
│ - Recover to last consistent    │
│   state                         │
│ - Time: 3-5 minutes             │
└──────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────┐
│ Step 6: Patroni Takeover         │
├──────────────────────────────────┤
│ - Stop PostgreSQL (manual)        │
│ - Start Patroni                  │
│ - Patroni starts PostgreSQL       │
│ - Patroni registers with etcd     │
│ - Patroni sets up replication     │
│ - Leader election occurs          │
└──────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────┐
│ Cluster Recovered!               │
├──────────────────────────────────┤
│ ✓ All nodes online               │
│ ✓ Primary elected                │
│ ✓ Replicas synced                │
│ ✓ Ready for traffic              │
└──────────────────────────────────┘
```

## Configuration Dependencies

### How Components Depend on Each Other

```
Patroni depends on:
├─ PostgreSQL installed and available
├─ etcd cluster operational
├─ pgBackRest (for backup info)
└─ Network connectivity to etcd

PostgreSQL depends on:
├─ OS-level resources (memory, disk)
└─ WAL directory writable

pgBackRest depends on:
├─ PostgreSQL running (for backups)
├─ Backup repository accessible
└─ Sufficient disk space

etcd depends on:
├─ Network connectivity among nodes
└─ Quorum (majority of nodes online)
```

### Configuration File Interactions

```
/etc/patroni/patroni.yml
    └─ Specifies PostgreSQL parameters
    └─ Points to /etc/pgbackrest/pgbackrest.conf

/etc/postgresql/15/main/postgresql.conf
    └─ Contains archive_command pointing to pgBackRest
    └─ Contains wal_level = replica (for standby)

/etc/pgbackrest/pgbackrest.conf
    └─ Defines stanza [demo]
    └─ Points to /mnt/pgbackrest-repo/
```

## Error Scenarios

### Component Failure Scenarios

```
If PostgreSQL fails:
├─ Patroni detects (health check fails)
├─ Sends ALERT to etcd
├─ Replicas see primary is down
├─ Leader election triggered
├─ One replica promoted to primary
└─ New replication established

If Primary Patroni fails:
├─ PostgreSQL keeps running (no auto stop)
├─ Replicas can't reach primary
├─ Replicas try to reconnect
├─ One replica eventually promoted
└─ Manual intervention might be needed

If etcd becomes unavailable:
├─ Patroni can't read/write cluster state
├─ Current primary continues running
├─ Replicas keep applying WAL
├─ No new leader election possible
├─ Wait for etcd to return
└─ Recovery when etcd is back

If pgBackRest backup fails:
├─ WAL archiving may still work
├─ Next backup attempt retries
├─ No impact on replication
└─ Manual restore not possible

If Backup Repository fails:
├─ New backups fail
├─ WAL archiving fails
├─ Existing backups still available
├─ Restore can still use existing backups
└─ Fix repository and retry backups
```

---

**Next:** Study [DATA_FLOW.md](DATA_FLOW.md) to understand how data moves through the system.
