# DEV291 Project Overview

## What is This Project?

This project provides a **complete, production-tested guide** to manually restore a **Patroni-managed PostgreSQL High Availability (HA) cluster** from a pgBackRest backup.

## 🎯 The Goal

Restore a 3-node PostgreSQL cluster that has failed or been reset to a clean sandbox environment, using backups created by pgBackRest, and verify that all data is intact and all nodes are synchronized.

## 🏗️ What is Patroni?

**Patroni** is an open-source template for PostgreSQL HA that:
- **Manages PostgreSQL** - Starts/stops PostgreSQL, handles configuration
- **Handles Failover** - Automatically promotes a replica if primary fails
- **Manages Elections** - Elects a leader among all nodes using distributed consensus
- **Monitors Health** - Continuously checks all nodes and replication status
- **Uses a DCS** - Stores cluster state in etcd (Distributed Configuration Store)

### Without Patroni:
```
Primary PostgreSQL (no monitoring) 
→ Fails → All replicas stop replicating → Manual intervention needed
```

### With Patroni:
```
Primary PostgreSQL → Fails → Patroni detects failure → 
Automatically promotes replica → New primary elected → 
Replicas auto-reconnect → Cluster continues
```

## 🔧 What is pgBackRest?

**pgBackRest** is a backup and restore tool specifically designed for PostgreSQL that:
- Creates **full** backups (complete copy of all data)
- Creates **differential** backups (changes since last full)
- Creates **incremental** backups (changes since last backup)
- Supports **parallel processing** - faster backups and restores
- **Compresses** backups to save storage
- **Encrypts** backups for security
- **Archives WAL** - stores transaction logs for recovery
- **Validates** backups - checks integrity before/after

## 🔄 The Restoration Challenge

When your cluster fails, here's what happens:

1. **Patroni and PostgreSQL stop working**
2. **Data directory may be corrupted or lost**
3. **You need to restore from backup**
4. **BUT:** pgBackRest restores only the data files, not the "system identifier"
5. **Patroni tracks cluster metadata in etcd** - which might be outdated
6. **You must coordinate:** PostgreSQL restore + Patroni cluster rebuild

## 9️⃣ Why 9 Steps?

Each step is necessary:

1. **Check Backups** - Ensure backups exist and are usable
2. **Stop Patroni** - Prevent conflicting cluster management
3. **Clean Data Dir** - Prepare for fresh restore
4. **Run Restore** - Copy backup data to server
5. **Verify Files** - Confirm restore was successful
6. **Fix Permissions** - PostgreSQL user must own files
7. **Start PostgreSQL** - Complete recovery process (replay WAL logs)
8. **Start Patroni** - Let Patroni take over management
9. **Verify Cluster** - Confirm all 3 nodes are healthy and synced

## 📊 System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    PATRONI CLUSTER (3 NODES)                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  PRIMARY NODE          REPLICA NODE 1     REPLICA NODE 2    │
│  ┌─────────────────┐   ┌──────────────┐   ┌──────────────┐ │
│  │  Patroni        │   │  Patroni     │   │  Patroni     │ │
│  │  (Leader)       │   │  (Follower)  │   │  (Follower)  │ │
│  ├─────────────────┤   ├──────────────┤   ├──────────────┤ │
│  │ PostgreSQL 15   │   │ PostgreSQL15 │   │ PostgreSQL15 │ │
│  │ (Running)       │   │ (Running)    │   │ (Running)    │ │
│  │ Data Dir:       │   │ Data Dir:    │   │ Data Dir:    │ │
│  │ /var/lib/..     │   │ /var/lib/..  │   │ /var/lib/..  │ │
│  │ 50GB            │   │ 50GB         │   │ 50GB         │ │
│  └─────────────────┘   └──────────────┘   └──────────────┘ │
│         │                     │                     │       │
│         │ ← Replication Stream → ← Replication Stream →     │
│         │                                                   │
│         └────────────────┬────────────────────────────────│  │
│                          │                                  │
│            ┌─────────────▼──────────────┐                  │
│            │ Distributed Config Store   │                  │
│            │ (etcd)                     │                  │
│            │ - Cluster state            │                  │
│            │ - Leader info              │                  │
│            │ - Member status            │                  │
│            │ - System identifiers       │                  │
│            └────────────────────────────┘                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 💾 Backup Strategy

**pgBackRest Backup Modes:**

```
Full Backup (Sunday):      [████████████████████] 50GB
  └─ All data, takes 30 min

Differential (Wed):        [████████████░░░░░░░░] 30GB
  └─ Changes since full, takes 15 min

Incremental (Daily):       [██░░░░░░░░░░░░░░░░░░] 5GB
  └─ Changes since last backup, takes 2 min

WAL Archive (continuous):  [Continuous streaming of transaction logs]
  └─ Enables point-in-time recovery
```

## 🔐 Why This Matters

### Data Loss Risk:
- **Without backups:** Data loss = total business loss
- **With pgBackRest:** Restore to specific point-in-time
- **With Patroni HA:** Automatic failover = zero downtime

### Recovery Time:
- **Manual process:** 2-3 hours + expertise
- **Automated process:** 20-30 minutes + validation
- **With proper testing:** Can recover reliably every time

## 📈 Project Scope

This project includes:

| Area | Coverage |
|------|----------|
| **Procedures** | 9-step process from backup to restored cluster |
| **Failures** | 3 real-world failures documented with fixes |
| **Checklists** | 4 operational checklists for validation |
| **Scripts** | 5 automated bash scripts for automation |
| **Diagrams** | Visual representations of architecture & flows |
| **References** | Links to official documentation |
| **Testing** | Test scenarios and validation procedures |

## 🎓 Technology Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| OS | Ubuntu 22.04 LTS | Operating System |
| PostgreSQL | 15 | Relational Database |
| Patroni | 3.x | HA Cluster Management |
| pgBackRest | 2.49+ | Backup & Restore Tool |
| etcd | Latest | Distributed Config Store |
| Python | 3.10+ | Patroni dependency |

## ✅ Expected Outcomes

After following this guide, you will:

1. ✅ Understand how Patroni HA clusters work
2. ✅ Know the complete 9-step restoration process
3. ✅ Be able to identify and fix common failures
4. ✅ Have automated scripts for future restores
5. ✅ Know how to validate cluster health
6. ✅ Understand best practices and lessons learned

## 🚀 How to Use This Project

**Start here:** [START_HERE.md](../START_HERE.md)

**For deep dives:**
- Architecture: [architecture/](../architecture/)
- Procedures: [procedures/](../procedures/)
- Failures: [failure-analysis/](../failure-analysis/)
- Checklists: [checklists/](../checklists/)
- Scripts: [scripts/](../scripts/)

**For quick reference:**
- QUICK_START.md (this section)
- TERMINOLOGY.md (this section)

## 📝 Key Takeaways

1. **Patroni automates HA management** - No manual failover needed
2. **pgBackRest provides reliable backup/restore** - Point-in-time recovery
3. **The 9-step process is essential** - Each step has a purpose
4. **Permission and configuration matter** - Small details cause big failures
5. **Validation is critical** - Always verify cluster health after restore
6. **Automation reduces human error** - Use scripts for consistency
7. **Testing is essential** - Practice restores regularly

## 🔗 Related Topics

- PostgreSQL High Availability
- Database Backup Strategies
- Disaster Recovery Planning
- Infrastructure as Code
- Operational Best Practices
- Database Replication

---

**Next:** Read [START_HERE.md](../START_HERE.md) or jump to [procedures/](../procedures/) to begin the restoration process.
