# Patroni Cluster Architecture

## Overview

The DEV291 project documents restoration of a **3-node Patroni cluster** for PostgreSQL High Availability.

## System Topology

### Logical Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                   PATRONI HA CLUSTER                              │
│                      (3 Nodes)                                    │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  ┌─────────────────────┐  ┌─────────────────┐ ┌──────────────┐   │
│  │ PRIMARY NODE        │  │ REPLICA NODE 1  │ │ REPLICA NODE2│   │
│  │ (Leader)            │  │                 │ │              │   │
│  ├─────────────────────┤  ├─────────────────┤ ├──────────────┤   │
│  │ Hostname: primary   │  │ Hostname: rep1  │ │ Hostname:rep2│   │
│  │ IP: 10.0.1.1        │  │ IP: 10.0.1.2    │ │ IP: 10.0.1.3 │   │
│  │ Port: 5432          │  │ Port: 5432      │ │ Port: 5432   │   │
│  │                     │  │                 │ │              │   │
│  │ ┌─────────────────┐ │  │ ┌─────────────┐ │ │ ┌──────────┐ │   │
│  │ │ Patroni 3.x     │ │  │ │ Patroni 3.x │ │ │ │ Patroni  │ │   │
│  │ │ (Manager)       │ │  │ │ (Manager)   │ │ │ │ (Manager)│ │   │
│  │ ├─────────────────┤ │  │ ├─────────────┤ │ │ ├──────────┤ │   │
│  │ │ PostgreSQL 15   │ │  │ │PostgreSQL 15│ │ │ │PostgreSQL│ │   │
│  │ │ (Running)       │ │  │ │ (Running)   │ │ │ │ (Running)│ │   │
│  │ │                 │ │  │ │             │ │ │ │          │ │   │
│  │ │ Role: PRIMARY   │ │  │ │ Role: STANDBY  │ │ │ Role:STBY│ │   │
│  │ │ Accepts: READ   │ │  │ │ Accepts:   │ │ │ │ Accepts: │ │   │
│  │ │          WRITE  │ │  │ │ READ only  │ │ │ │ READ only│ │   │
│  │ │                 │ │  │ │             │ │ │ │          │ │   │
│  │ │ Data: 50GB      │ │  │ │ Data: 50GB  │ │ │ │Data: 50GB│ │   │
│  │ │ /var/lib/..     │ │  │ │ /var/lib/.. │ │ │ │ /var/..  │ │   │
│  │ └─────────────────┘ │  │ └─────────────┘ │ │ └──────────┘ │   │
│  └──────────┬──────────┘  └────────┬────────┘ └──────┬───────┘   │
│             │                      │                 │            │
│             │ Replication Stream (WAL streaming)     │            │
│             ├──────────────────────┼─────────────────┤            │
│             │ - Real-time sync    │ - Apply changes │            │
│             │ - Heartbeat         │ - Maintain copy │            │
│             └─────────┬───────────┘                 │            │
│                       │                             │            │
│          ┌────────────▼──────────┐                 │            │
│          │ Distributed Config    │                 │            │
│          │ Store (etcd)          │                 │            │
│          │                       │                 │            │
│          │ Stores:               │                 │            │
│          │ - Leader info         │                 │            │
│          │ - Member status       │                 │            │
│          │ - Cluster state       │                 │            │
│          │ - System identifiers  │                 │            │
│          │ - Config parameters   │                 │            │
│          │                       │                 │            │
│          │ All 3 nodes read/     │                 │            │
│          │ write to etcd         │                 │            │
│          └────────────┬──────────┘                 │            │
│                       │                            │            │
│                       └────────────────────────────┘            │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘

External Systems:
┌────────────────────────────────────────────────────────────────────┐
│ BACKUP REPOSITORY                                                 │
│ Location: /mnt/pgbackrest-repo/                                   │
│                                                                    │
│ ┌─────────────────────────────────────────────────────────────┐   │
│ │ Backup Storage:                                             │   │
│ │ - Full backups                                              │   │
│ │ - Differential backups                                      │   │
│ │ - Incremental backups                                       │   │
│ │ - WAL archives (Write-Ahead Logs)                           │   │
│ │                                                              │   │
│ │ Space: 500GB (compressed)                                   │   │
│ │ Retention: 30 days                                          │   │
│ │ Owner: postgres:postgres                                    │   │
│ └─────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────┘
```

## Node Specifications

### Primary Node (Leader)

| Property | Value | Notes |
|----------|-------|-------|
| **Hostname** | primary | Resolvable in DNS/hosts |
| **IP Address** | 10.0.1.1 | Internal network |
| **PostgreSQL Port** | 5432 | Standard port |
| **OS** | Ubuntu 22.04 LTS | Focal |
| **PostgreSQL Version** | 15 | Latest stable |
| **Patroni Version** | 3.x | HA template |
| **RAM** | 16GB | Minimum |
| **CPU** | 4 cores | Minimum |
| **Disk Space** | 500GB | Data + backups |
| **Data Directory** | /var/lib/postgresql/15/main | Standard location |
| **WAL Location** | /var/lib/postgresql/15/main/pg_wal | Default |
| **Backup Repository** | /mnt/pgbackrest-repo | NFS or local |
| **Config Files** | /etc/patroni/patroni.yml | Patroni config |
| | /etc/pgbackrest/pgbackrest.conf | Backup config |
| | /etc/postgresql/15/main/postgresql.conf | PostgreSQL config |

### Replica Nodes (Followers)

| Property | Value | Notes |
|----------|-------|-------|
| **Hostnames** | replica-1, replica-2 | Resolvable |
| **IP Addresses** | 10.0.1.2, 10.0.1.3 | Internal network |
| **PostgreSQL Port** | 5432 | Same as primary |
| **OS** | Ubuntu 22.04 LTS | Identical to primary |
| **PostgreSQL Version** | 15 | Identical to primary |
| **Patroni Version** | 3.x | Identical to primary |
| **RAM** | 16GB | Minimum |
| **CPU** | 4 cores | Minimum |
| **Disk Space** | 500GB | Identical to primary |
| **Data Directory** | /var/lib/postgresql/15/main | Identical |
| **WAL Location** | /var/lib/postgresql/15/main/pg_wal | Identical |
| **Backup Repository** | /mnt/pgbackrest-repo | Shared (NFS) |
| **Config Files** | Identical to primary | Except hostname/IP |

## Network Architecture

### IP Addressing

```
┌─────────────────────────────────────────┐
│ Internal Network: 10.0.1.0/24           │
├─────────────────────────────────────────┤
│ 10.0.1.1   - Primary (leader)           │
│ 10.0.1.2   - Replica 1                  │
│ 10.0.1.3   - Replica 2                  │
│ 10.0.1.100 - VIP (Virtual IP) optional  │
└─────────────────────────────────────────┘

External Network (Optional):
┌─────────────────────────────────────────┐
│ External: 192.168.1.0/24 (optional)     │
├─────────────────────────────────────────┤
│ 192.168.1.11 - Primary external         │
│ 192.168.1.12 - Replica 1 external       │
│ 192.168.1.13 - Replica 2 external       │
└─────────────────────────────────────────┘
```

### Network Connectivity

```
Primary → Replica 1:  Replication stream (TCP 5432)
Primary → Replica 2:  Replication stream (TCP 5432)
Replica 1 → Replica 2: No direct connection

All → etcd: DCS communication (TCP 2379)
All → Backup Repo: Backup/restore (SSH or NFS)
```

## Storage Architecture

### Data Directory Layout

```
/var/lib/postgresql/15/main/
├── base/                    # Actual table data
│   ├── 1/                  # System database (template0, template1)
│   ├── 16385/              # Your database
│   │   ├── 16386           # Table OID 16386
│   │   ├── 16386.1         # First extent
│   │   ├── 16386.2         # Second extent
│   │   └── ...
│   └── ...
├── global/                  # Global objects (roles, tablespaces)
├── pg_wal/                 # Write-Ahead Logs (active transaction logs)
│   ├── 000000010000000000000001
│   ├── 000000010000000000000002
│   └── ... (WAL files)
├── pg_tblspc/              # Tablespace symlinks
├── pg_stat_tmp/            # Statistics temp files
├── pg_notify/              # LISTEN/NOTIFY data
├── pg_serial/              # Serialization info
├── pg_snapshots/           # Snapshot data
├── pg_logical/             # Logical decoding
├── PG_VERSION              # PostgreSQL version (15)
├── postgresql.auto.conf    # Auto-generated config
├── postgresql.conf         # PostgreSQL config (or include)
├── pg_ident.conf          # Ident authentication
├── pg_hba.conf            # Host-based authentication
├── backup_label           # Created during backup (temp)
└── pg_control            # Cluster control file (critical!)
```

### Backup Repository Layout

```
/mnt/pgbackrest-repo/
└── demo/                      # Stanza: demo
    ├── backup/
    │   ├── full-backup-1/     # Full backup from 2026-04-10
    │   │   ├── backup.info
    │   │   └── ... (backup data)
    │   ├── diff-backup-1/     # Differential from 2026-04-12
    │   │   ├── backup.info
    │   │   └── ... (backup data)
    │   └── incr-backup-1/     # Incremental from 2026-04-14
    │       ├── backup.info
    │       └── ... (backup data)
    └── wal/                    # WAL archives
        ├── 00000001/
        │   ├── 000000010000000000000001  # WAL segment
        │   ├── 000000010000000000000002
        │   └── ...
        └── ... (many WAL segments)
```

## Service Architecture

### Patroni Components

```
Patroni Daemon
├── PostgreSQL Wrapper
│   ├── Start/stop PostgreSQL
│   ├── Monitor health
│   ├── Apply configuration
│   └── Manage replication
├── DCS Client (etcd)
│   ├── Get cluster state
│   ├── Write node status
│   ├── Participate in elections
│   └── Get leader info
├── API Server
│   ├── Serve /health endpoint
│   ├── Serve /cluster endpoint
│   └── Accept commands
└── Monitoring
    ├── Check PostgreSQL health
    ├── Check replication lag
    ├── Monitor etcd connectivity
    └── Detect failures
```

### etcd Architecture

```
etcd Cluster
├── Node 1 (primary):   10.0.1.1:2379
├── Node 2 (replica-1): 10.0.1.2:2379
└── Node 3 (replica-2): 10.0.1.3:2379

Key Structure:
/patroni/
├── demo/                    # Cluster name
│   ├── initialize           # Cluster initialized flag
│   ├── leader               # Current leader node name
│   ├── members/
│   │   ├── primary          # Primary node data
│   │   ├── replica-1        # Replica 1 data
│   │   └── replica-2        # Replica 2 data
│   ├── failover             # Failover state
│   └── config               # Cluster configuration
```

## Resource Requirements

### Minimum Hardware

| Component | Requirement |
|-----------|-------------|
| **CPU** | 4 cores per node |
| **RAM** | 16GB per node |
| **Disk - Data** | 500GB minimum |
| **Disk - Backups** | 500GB minimum |
| **Network** | 1Gbps minimum |

### Recommended Hardware

| Component | Recommendation |
|-----------|----------------|
| **CPU** | 8+ cores per node |
| **RAM** | 32GB+ per node |
| **Disk - SSD** | NVMe SSD for data directory |
| **Disk - Backups** | Separate disk for backups |
| **Network** | 10Gbps or better |

### Disk Space Planning

```
Database Size:           50GB
WAL retention (7 days):  50GB
Backups (30 days):      150GB
Replication overhead:    10GB
System/misc:             10GB
─────────────────────────────
Total per node:         200-300GB
```

## Failover Behavior

### Normal Operation (No Failure)

```
Client ──→ [Primary] ──→ [Replica-1]
              │            ↓
              │        [Replica-2]
              │
          Replication
          Streaming
```

### Primary Fails → Automatic Failover

```
Step 1: Primary fails
  [Primary X] [Replica-1] [Replica-2]
  
Step 2: Patroni detects failure (within 3-5 seconds)
  [Primary X] [Replica-1*] [Replica-2]  (* Candidate)
  
Step 3: Leader election in etcd (consensus)
  [Primary X] [Replica-1 ELECTED] [Replica-2]
  
Step 4: Replica-1 promoted to Primary
  [Primary X] [Replica-1 → Primary] [Replica-2]
  
Step 5: Replica-2 reconnects to new Primary
  [Primary X] [New Primary] → [Replica-2]
  
Result: Zero downtime, no data loss (with sync replication)
```

## Replication Architecture

### Synchronous Replication Flow

```
Client writes transaction on Primary
          ↓
Primary writes to WAL
          ↓
Primary sends WAL to all Replicas
          ↓
Replicas write to their WAL
          ↓
Replicas acknowledge receipt
          ↓
Primary confirms transaction
          ↓
Client receives ACK
```

**Guarantee:** If Primary fails, all committed transactions exist on at least one Replica.

## Restoration Sequence

### Data Flow During Restore

```
pgBackRest Backup Repository
  ├─ Full Backup (2026-04-10)
  ├─ Differential Backup (2026-04-12)
  └─ WAL Files (continuous)
            ↓
   (Select restore point)
            ↓
  pgBackRest Restore Process
  ├─ Copy backup data
  ├─ Apply WAL files
  └─ Recover to consistent state
            ↓
  Data Directory
  /var/lib/postgresql/15/main/
            ↓
  PostgreSQL Recovery
  ├─ Read pg_control
  ├─ Replay WAL log
  └─ Reach consistent state
            ↓
  Ready for Patroni Takeover
            ↓
  Patroni Assumes Control
  ├─ Update etcd metadata
  ├─ Configure replication
  └─ Cluster operational
```

---

**Next:** Study [COMPONENT_INTERACTION.md](COMPONENT_INTERACTION.md) to understand how components work together.
