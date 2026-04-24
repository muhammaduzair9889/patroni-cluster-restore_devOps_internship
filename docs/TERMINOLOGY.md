# Key Terminology - DEV291 Glossary

## General Database Terms

### ACID Properties
**Atomicity, Consistency, Isolation, Durability** - Guarantees that database transactions are reliable.
- Atomicity: Transaction completes fully or not at all
- Consistency: Database moves from one valid state to another
- Isolation: Transactions don't interfere with each other
- Durability: Completed transactions persist even after failure

### Transaction Log / Write-Ahead Log (WAL)
Sequential record of all changes to the database. Used to:
- Recover database after crash
- Replicate changes to standby servers
- Create backups with point-in-time recovery

### Full Backup
Complete copy of entire PostgreSQL data directory. First backup must be full; later backups reference this baseline.

### Differential Backup
Backup of changes since the last full backup. Faster than full, but requires full backup to restore.

### Incremental Backup
Backup of changes since the last backup (full or differential). Smallest backup, fastest creation.

### Point-in-Time Recovery (PITR)
Ability to restore database to any specific moment in time (down to seconds). Requires full backup + WAL archives.

### System Identifier
Unique 64-bit number generated when PostgreSQL cluster is initialized. Must be identical on all replicas. **Critical for Patroni cluster synchronization.**

### Data Directory
Default location: `/var/lib/postgresql/15/main` - Contains all database files, indexes, configuration, and WAL logs.

## Patroni-Specific Terms

### Patroni
Open-source template for PostgreSQL HA. Manages:
- PostgreSQL process (start/stop/restart)
- Leader election among nodes
- Cluster topology and state
- Automatic failover
- Replication management

### High Availability (HA)
System designed to remain operational even when components fail. For database:
- Primary node handles writes
- Replica nodes handle reads
- Automatic failover if primary fails
- Transparent to applications

### Primary Node / Leader
The active PostgreSQL database that:
- Accepts client connections
- Processes read AND write queries
- Streams changes to replica nodes
- Elected by Patroni consensus

### Replica Node / Follower / Standby
PostgreSQL instance that:
- Reads and applies changes from primary
- Accepts read-only client connections
- Can be promoted to primary if primary fails
- Has exact copy of primary's data

### Replication
Process of copying data changes from primary to replicas in real-time:
- Primary writes transaction → WAL
- Replica reads WAL → applies changes
- Ensures replica has near-identical copy of data
- Replication lag = time behind primary

### Replication Stream
Continuous connection from primary to replica for sending WAL data.

### Synchronous Replication
Primary waits for replica confirmation before completing transaction. Slower but safer - zero data loss if primary fails.

### Asynchronous Replication
Primary does not wait for replica. Faster but risk of data loss if primary fails before replica applies changes.

### Leader Election
Process of choosing which replica becomes new primary if current primary fails. Uses:
- Distributed consensus (etcd)
- Quorum voting (requires majority)
- Priority settings

### Split-Brain
Dangerous condition where multiple nodes think they're the primary, causing:
- Conflicting writes
- Data inconsistency
- Replication failure
**Prevention:** Always stop Patroni on all nodes before maintenance

### Distributed Configuration Store (DCS)
External system (etcd) that:
- Stores cluster state
- Coordinates leader elections
- Prevents split-brain scenarios
- Maintains consensus

### etcd
Distributed key-value store used by Patroni for:
- Cluster state (who is primary, who are replicas)
- Leader election
- Configuration management
- Failure detection

### Patroni Configuration File
Location: `/etc/patroni/patroni.yml` - Contains:
- Cluster name
- Node name
- PostgreSQL parameters
- Replication settings
- DCS connection info
- Resource constraints

### Patronictl
Command-line tool to:
- View cluster status (`patronictl list`)
- Promote replica to primary (`patronictl failover`)
- Remove failed members
- Edit cluster configuration

## pgBackRest-Specific Terms

### pgBackRest
Production-grade backup tool for PostgreSQL providing:
- Multiple backup types (full, differential, incremental)
- Parallel processing
- Compression
- Encryption
- WAL archiving
- Backup validation

### Stanza
Named backup set in pgBackRest - Contains:
- One or more backups
- WAL archives
- Configuration specific to this database

Example: `[demo]` stanza = all backups for "demo" database

### Backup Repository
Central location where pgBackRest stores all backups and WAL archives:
- Can be local filesystem (e.g., `/mnt/pgbackrest-repo/`)
- Can be cloud storage (S3, GCS, Azure)
- Must be accessible from all PostgreSQL nodes
- Must have sufficient disk space

### Delta Restore
`pgbackrest restore --delta` - Faster restore method that:
- Compares existing data with backup
- Only writes files that differ
- Skips unchanged files
- Safer than full wipe + restore

### Full Restore
`pgbackrest restore` (without --delta) - Removes all data, restores from backup.

### WAL Archiving
Continuous process of copying WAL files to backup repository:
- Enables point-in-time recovery
- Stores complete transaction history
- Can span months/years

### pgBackRest Configuration File
Location: `/etc/pgbackrest/pgbackrest.conf` - Contains:
- Repository path/connection info
- Stanza definitions
- Backup settings
- WAL archiving settings

### pgbackrest info
Command showing available backups:
- Backup timestamps
- Backup types (full/diff/incr)
- Backup status (OK, running)
- Database version
- System identifier

## Operational Terms

### Restore
Process of copying backed-up data back to database server:
- Restores data files from backup
- Replays WAL for recovery
- Brings database to consistent state
- Takes 5-20 minutes depending on size

### WAL Replay / Recovery
PostgreSQL process of:
- Reading transaction logs (WAL)
- Applying transactions to data files
- Bringing database to consistent state
- Happens during startup after restore

### Cluster Synchronization
State where:
- All nodes have same data
- Replicas are caught up with primary
- Zero replication lag
- Safe for failover

### Health Check
Verification that cluster is:
- All nodes online
- Primary elected
- Replication working
- Zero data loss

### Failover
Automatic promotion of replica to primary when primary fails:
- etcd detects primary failure
- Replica wins election (based on priority)
- Patroni promotes winning replica
- Other replicas reconnect to new primary

### Downtime
Time when cluster is not accepting connections:
- During planned maintenance: seconds (with Patroni HA)
- During unplanned failure: seconds (automatic failover)
- During restore: 20-30 minutes (full process)

### Recovery Time Objective (RTO)
Target time to restore service after failure. With Patroni: seconds (automatic).

### Recovery Point Objective (RPO)
Maximum acceptable data loss. With Patroni + pgBackRest: minutes to hours (depends on backup frequency).

## File & Permission Terms

### File Ownership
`postgres:postgres` - Files must be owned by postgres user and postgres group:
- PostgreSQL requires this to read/write files
- Wrong ownership = "Permission denied" errors
- Fix: `chown -R postgres:postgres /var/lib/postgresql/15/main`

### File Permissions / Mode
`0700` for data directory:
- 7 = owner (postgres) can read/write/execute
- 0 = group has no permissions
- 0 = others have no permissions
- Fix: `chmod 0700 /var/lib/postgresql/15/main`

### File Permissions / Mode
`0600` for individual files within data directory:
- 6 = owner (postgres) can read/write
- 0 = group cannot access
- 0 = others cannot access

### sudo / Privilege Escalation
Running commands as root/superuser:
- All restore commands require `sudo`
- SSH key-based auth prevents password prompts
- Configure sudoers for passwordless execution

## Monitoring Terms

### Cluster Member Status
From `patronictl list`:
- **running** = PostgreSQL is running
- **stopped** = PostgreSQL is not running
- **failure** = Node unavailable or unhealthy

### Node Role
From `patronictl list`:
- **L** = Leader (Primary)
- **F** = Follower (Replica)
- **U** = Undefined (not yet assigned)

### Replication Lag
Time difference between:
- Master's latest transaction
- Replica's latest applied transaction
- Goal: < 1 second
- OK: < 10 seconds
- Warning: > 30 seconds

### Lag Bytes
Amount of WAL data not yet applied on replica:
- Shows `0` when in sync
- Increases during heavy load
- Decreases as replica catches up

### Healthy Cluster
- All 3 nodes are "running"
- One node is "L" (leader)
- Two nodes are "F" (followers)
- All nodes have 0 lag
- No alerts or warnings

## Common Abbreviations

| Abbrev | Meaning |
|--------|---------|
| HA | High Availability |
| RTO | Recovery Time Objective |
| RPO | Recovery Point Objective |
| WAL | Write-Ahead Log |
| DCS | Distributed Configuration Store |
| PITR | Point-in-Time Recovery |
| ACID | Atomicity, Consistency, Isolation, Durability |
| IOPS | Input/Output Operations Per Second |
| GB | Gigabyte |
| TB | Terabyte |
| min | minute(s) |
| sec | second(s) |

---

**Using these terms:** When you see unfamiliar terminology in procedures or troubleshooting, return to this glossary for quick reference.
