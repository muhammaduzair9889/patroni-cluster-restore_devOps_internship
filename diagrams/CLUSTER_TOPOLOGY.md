# CLUSTER_TOPOLOGY - Architecture Diagram

## 3-Node Patroni Cluster Topology

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           3-NODE CLUSTER TOPOLOGY                       │
└─────────────────────────────────────────────────────────────────────────┘

                          ┌──────────────────┐
                          │   etcd Cluster   │
                          │  (Leader/Peers)  │
                          └────────┬─────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    │              │              │
        ┌───────────▼────────┐ ┌──▼──────────────┐ ┌─────────────────┐
        │   PRIMARY NODE     │ │  REPLICA-1      │ │   REPLICA-2     │
        │  10.0.0.1:5432     │ │ 10.0.0.2:5432   │ │ 10.0.0.3:5432   │
        └───────────┬────────┘ └──┬──────────────┘ └────────┬────────┘
                    │             │                         │
        ┌───────────┴─────────┬───┴────────┬────────────────┴────────┐
        │                     │            │                         │
    ┌───▼──────┐  ┌──────────▼──┐  ┌─────▼──────┐  ┌────────────────▼──┐
    │PostgreSQL│  │  PostgreSQL │  │ PostgreSQL │  │ Backup Repository  │
    │    15    │  │      15     │  │     15     │  │ /mnt/pgbackrest    │
    │ (Leader) │  │  (Follower) │  │ (Follower) │  │                    │
    ├──────────┤  ├─────────────┤  ├────────────┤  ├────────────────────┤
    │ Patroni  │  │   Patroni   │  │  Patroni   │  │ pgBackRest         │
    │  3.x     │  │    3.x      │  │   3.x      │  │ 2.49 (Restore)     │
    └──────────┘  └─────────────┘  └────────────┘  └────────────────────┘
        │             │                   │                 │
        └──────┬──────┴───────────┬───────┴─────────────────┘
               │                  │
        ┌──────▼──────────────────▼──┐
        │    Synchronous Replication │
        │  (2 synchronous standby)    │
        └─────────────────────────────┘


NETWORK CONNECTIONS:
═════════════════════

Primary ↔ Replica-1  : TCP 5432 (PostgreSQL), TCP 2379/2380 (etcd)
Primary ↔ Replica-2  : TCP 5432 (PostgreSQL), TCP 2379/2380 (etcd)
Replica-1 ↔ Replica-2: TCP 5432 (PostgreSQL), TCP 2379/2380 (etcd)

All nodes ↔ Repository: TCP 22 (SSH), /mnt/pgbackrest-repo (NFS/mount)


DATA FLOW:
══════════

WRITE OPERATIONS:
  Client → Primary → WAL → Replicas (synchronous replication)
           ↓
           Backup Repository (via pgBackRest)

READ OPERATIONS:
  Client → Primary (if consistency required)
  Client → Replicas (if read-only acceptable)


STORAGE LAYOUT:
═══════════════

PRIMARY NODE:
├─ /var/lib/postgresql/15/main/      ← PostgreSQL data
│  ├─ base/                           ← Database objects
│  ├─ global/                         ← Cluster-wide objects
│  ├─ pg_wal/                         ← Write-ahead logs
│  ├─ pg_control                      ← Cluster control file
│  └─ postgresql.conf                 ← Configuration
├─ /var/log/postgresql/               ← PostgreSQL logs
├─ /var/lib/patroni/                  ← Patroni state
└─ /etc/patroni/                      ← Patroni configuration

REPLICA NODES: Same as primary (data replicates via streaming)

BACKUP REPOSITORY:
├─ /mnt/pgbackrest-repo/
│  └─ demo/                           ← Stanza (cluster name)
│     ├─ backup/                      ← Full backups
│     │  └─ [date]/                   ← Timestamped backups
│     ├─ wal/                         ← WAL files
│     └─ pg_wal_history/              ← WAL timeline history


RESOURCE REQUIREMENTS:
══════════════════════

Each Node (Primary + 2 Replicas):
├─ CPU: 4-8 cores (multi-threaded queries)
├─ RAM: 16-32 GB (PostgreSQL cache)
├─ Disk: 200 GB+ (depends on database size)
└─ Network: 1 Gbps+ (replication sync)

Backup Repository:
├─ Disk: 500 GB - 2 TB (3+ backups + WAL archive)
├─ Network: 1 Gbps+ (backup/restore traffic)
└─ Availability: 99.9% uptime recommended


FAILOVER SEQUENCE:
═══════════════════

1. Primary fails
2. etcd detects failure (heartbeat timeout)
3. Remaining replicas vote for new leader
4. Replica with latest WAL becomes new primary
5. Former primary promoted to replica (if recovered)


RESTORATION FLOW:
═════════════════

Original Failure:
  Primary ✗ → Replica-1 (elected new leader)
                        ↓
                    Cluster stable (degraded)

Restore Process:
  Primary ✗ → Clean disk → Restore from backup → Start PostgreSQL
                                                    ↓
                                            Connect as replica
                                                    ↓
                                            Back to 3-node cluster


MONITORING POINTS:
═══════════════════

Essential Metrics:
├─ Replication lag (should be < 100ms)
├─ Synchronous standby status
├─ WAL position on all nodes
├─ Disk space remaining
├─ PostgreSQL process status
├─ etcd cluster health
└─ Network latency between nodes


See Also:
─────────
- [COMPONENT_INTERACTION.md](COMPONENT_INTERACTION.md) - Detailed component roles
- [DATA_FLOW.md](DATA_FLOW.md) - Data movement during operations
- [../procedures/](../procedures/) - Step-by-step restoration
