# PostgreSQL 15 Configuration for HA Cluster

Reference configuration for PostgreSQL 15 when used with Patroni.

**Location:** `/etc/postgresql/15/main/postgresql.conf`

## Critical Settings (Required for HA)

```postgresql
# Network
listen_addresses = '*'
port = 5432

# Replication (REQUIRED for Patroni)
wal_level = replica
max_wal_senders = 10
max_replication_slots = 10
wal_keep_size = 2GB

# Hot Standby
hot_standby = on
hot_standby_feedback = on

# Synchronous Replication
synchronous_commit = 'remote_apply'
synchronous_standby_names = 'ANY 1 (*)'
```

## Memory & Performance

```postgresql
# Shared buffers - ~25% of system RAM
shared_buffers = 4GB

# Effective cache - ~75% of system RAM
effective_cache_size = 12GB

# Work memory per operation
work_mem = 13MB

# Maintenance work memory
maintenance_work_mem = 1GB

# Checkpoint settings
checkpoint_timeout = 30min
checkpoint_completion_target = 0.9
wal_buffers = 16MB
```

## Logging

```postgresql
# Logging
log_min_duration_statement = 1000       # Log queries > 1 second
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_statement = 'ddl'
log_duration = off
log_min_messages = 'notice'
```

## WAL Archiving (For pgBackRest)

```postgresql
# Archive mode
archive_mode = on
archive_command = 'pgbackrest --stanza=demo archive-push %p'
archive_timeout = 300
```

## Connection Settings

```postgresql
# Connections
max_connections = 300
max_prepared_transactions = 0
idle_in_transaction_session_timeout = 60000

# Connection pooling (if using PgBouncer)
session_preload_libraries = '$libdir/pgbouncer_pool_mode'
```

## Full Example

```postgresql
# PostgreSQL 15 Configuration for Patroni HA

#----------
# Network
#----------
listen_addresses = '*'
port = 5432
unix_socket_directories = '/var/run/postgresql'
tcp_keepalives_idle = 900
tcp_keepalives_interval = 900
tcp_keepalives_count = 5

#----------
# Connections
#----------
max_connections = 300
superuser_reserved_connections = 3
max_prepared_transactions = 0
idle_in_transaction_session_timeout = 60000
statement_timeout = 0

#----------
# Memory
#----------
shared_buffers = 4GB
effective_cache_size = 12GB
work_mem = 13MB
maintenance_work_mem = 1GB

#----------
# WAL & Checkpoints
#----------
wal_level = replica
wal_buffers = 16MB
wal_writer_delay = 200ms
wal_writer_flush_after = 1MB
checkpoint_timeout = 30min
checkpoint_completion_target = 0.9
max_wal_size = 4GB

#----------
# Replication (REQUIRED for Patroni)
#----------
max_wal_senders = 10
max_replication_slots = 10
wal_keep_size = 2GB

#----------
# Hot Standby
#----------
hot_standby = on
hot_standby_feedback = on
hot_standby_max_standby_id_xacts = 1000000
hot_standby_max_standby_archive_delay = 10min

#----------
# Synchronous Replication
#----------
synchronous_commit = 'remote_apply'
synchronous_standby_names = 'ANY 1 (*)'

#----------
# Archiving (pgBackRest)
#----------
archive_mode = on
archive_command = 'pgbackrest --stanza=demo archive-push %p'
archive_timeout = 300

#----------
# Logging
#----------
log_min_duration_statement = 1000
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_statement = 'ddl'
log_duration = off
log_min_messages = 'notice'
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_directory = '/var/log/postgresql'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_truncate_on_rotation = on
log_rotation_age = 1d
log_rotation_size = 100MB
logging_collector = on

#----------
# Query Tuning
#----------
random_page_cost = 1.1
effective_io_concurrency = 200
min_wal_size = 2GB
max_wal_size = 4GB

#----------
# Autovacuum
#----------
autovacuum = on
autovacuum_naptime = 1min
autovacuum_vacuum_scale_factor = 0.1
autovacuum_vacuum_insert_scale_factor = 0.05
autovacuum_max_workers = 3

#----------
# Client Connection Defaults
#----------
datestyle = 'iso, mdy'
timezone = 'UTC'
lc_messages = 'en_US.UTF-8'
lc_monetary = 'en_US.UTF-8'
lc_numeric = 'en_US.UTF-8'
lc_time = 'en_US.UTF-8'
default_text_search_config = 'pg_catalog.english'
```

## pg_hba.conf Configuration

```
# Allow local connections
local   all             all                                   trust

# IPv4 local connections
host    all             all        127.0.0.1/32              md5
host    all             all        ::1/128                   md5

# Replication (adjust subnet for your network)
host    replication     replicator 10.0.0.0/8               md5

# Application connections
host    all             all        10.0.0.0/8               md5
```

## Important Notes

### For Patroni-Managed Clusters

1. **Don't modify** these settings - Patroni manages them:
   - `wal_level`
   - `max_wal_senders`
   - `max_replication_slots`
   - `hot_standby`
   - `synchronous_commit`

2. **Do customize** these per your environment:
   - `shared_buffers` - Based on available RAM
   - `effective_cache_size` - Typically 75% of RAM
   - `work_mem` - Based on max_connections
   - `max_connections` - Based on application needs

3. **Monitor** these settings:
   - `wal_keep_size` - Should not fill disk
   - `checkpoint_timeout` - Affects recovery time
   - `log_min_duration_statement` - Tune for workload

### Calculating work_mem

```
work_mem = (available_RAM - shared_buffers) / (max_connections * 2)

Example with 16GB RAM:
available = 16GB - 4GB (shared_buffers) = 12GB
work_mem = 12GB / (300 * 2) = 12GB / 600 = 20MB
Reasonable value: 13MB (to be conservative)
```

## Validation

```bash
# Check current settings
sudo -u postgres psql -c "SHOW shared_buffers;"
sudo -u postgres psql -c "SHOW effective_cache_size;"
sudo -u postgres psql -c "SHOW work_mem;"

# View all non-default settings
sudo -u postgres psql -c "SELECT name, setting FROM pg_settings WHERE source NOT LIKE 'default%' ORDER BY name;"

# Check replication settings
sudo -u postgres psql -c "SHOW wal_level;"
sudo -u postgres psql -c "SHOW max_wal_senders;"
sudo -u postgres psql -c "SHOW synchronous_commit;"
```

## Before Deployment

1. **Adjust for your hardware** - Set shared_buffers and effective_cache_size
2. **Test in sandbox** - Verify all settings work with your workload
3. **Monitor initially** - Watch logs for any warnings or errors
4. **Plan WAL archiving** - Ensure pgBackRest archive paths are correct
5. **Test failover** - Verify Patroni can manage the configuration

See [../../procedures/](../../procedures/) for step-by-step restore instructions.
