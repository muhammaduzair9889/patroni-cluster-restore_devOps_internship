# Automation Scripts

This section contains bash scripts to automate Patroni cluster restoration.

## Scripts Included

### pre_restore_check.sh
Pre-restore validation script that checks:
- Backup integrity and availability
- System resources and disk space
- All nodes accessible
- File permissions and configurations
- etcd health
- Network connectivity

**Usage:**
```bash
bash pre_restore_check.sh
```

### restore_cluster.sh
Automated restore script that:
- Runs all 9 restoration steps
- Handles errors gracefully
- Logs all output
- Provides progress updates
- Generates completion report

**Usage:**
```bash
bash restore_cluster.sh [options]
```

### verify_cluster.sh
Post-restore verification script that:
- Checks all 3 nodes online
- Validates replication
- Verifies data integrity
- Tests connectivity
- Generates health report

**Usage:**
```bash
bash verify_cluster.sh
```

### backup_info.sh
Lists available backups with details:
- Backup dates
- Backup sizes
- Backup status
- Retention info

**Usage:**
```bash
bash backup_info.sh [stanza_name]
```

### monitoring.sh
Real-time cluster monitoring that:
- Shows cluster status
- Tracks replication lag
- Monitors disk usage
- Displays system metrics

**Usage:**
```bash
bash monitoring.sh [interval_seconds]
```

## How to Use

1. Review script before running
2. Adapt to your environment (paths, hosts, etc.)
3. Test in sandbox environment first
4. Include in your automation/deployment system
5. Monitor output and logs

## Warnings

- Always test scripts in non-production first
- Review error handling logic
- Ensure proper logging for audit trail
- Have manual procedures as fallback
- Monitor automated restore closely first time

## Integration

These scripts can be integrated with:
- Cron jobs for scheduled testing
- Jenkins/GitLab CI for automated testing
- Terraform for infrastructure automation
- Ansible for multi-node orchestration
- Monitoring systems for alerting

## Troubleshooting Scripts

If a script fails:
1. Check error output
2. Review [../failure-analysis/](../failure-analysis/) for known issues
3. Check log files listed in script output
4. Manually perform step if needed
5. Report issue with logs attached
