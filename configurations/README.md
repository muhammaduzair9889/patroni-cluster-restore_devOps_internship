# Configuration Files & Examples

This section contains example configuration files for the Patroni cluster restoration.

## Files in This Directory

### PATRONI_CONFIG.yml
Complete Patroni configuration example including:
- Cluster settings
- PostgreSQL parameters
- DCS (etcd) connection
- Replication settings
- Monitoring parameters

### PGBACKREST_CONFIG.conf
pgBackRest configuration example with:
- Repository paths
- Stanza configuration
- Backup settings
- WAL archiving settings
- Retention policies

### POSTGRESQL_CONFIG.md
PostgreSQL configuration recommendations:
- WAL settings for replication
- Replication slots
- Archive command
- Synchronous replication
- Performance tuning

### ETCD_CONFIG.md
etcd setup and configuration:
- Cluster initialization
- Member configuration
- Security settings
- Backup procedures

## How to Use

1. Review examples in this directory
2. Adapt to your specific environment
3. Consider your:
   - Cluster size
   - Network topology
   - Backup repository location
   - Recovery requirements

## Important Notes

- All configs shown are EXAMPLES
- Customize for your environment
- Test changes before production
- Document any customizations
- Keep configs synchronized across nodes
