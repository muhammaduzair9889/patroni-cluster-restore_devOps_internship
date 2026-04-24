# Checklists & Operational Procedures

This section contains operational checklists for restore verification.

## Files in This Directory

### PRE_RESTORE_CHECKLIST.md
Comprehensive checklist to run BEFORE starting restore:
- Verify backups exist and are valid
- Check system resources and disk space
- Verify all nodes are accessible
- Check file permissions and configurations
- Ensure etcd is healthy
- Network connectivity

### DURING_RESTORE_CHECKLIST.md
Step-by-step checklist to follow WHILE performing restore:
- Verify each step completes successfully
- Watch for errors in logs
- Monitor disk space and resources
- Time each phase for future reference

### POST_RESTORE_CHECKLIST.md
Comprehensive checks AFTER restore completes:
- Verify all 3 nodes are online
- Check cluster health
- Verify replication working
- Test database connectivity
- Verify data integrity
- Document results

### HEALTH_CHECK_CHECKLIST.md
Quick cluster health verification (for ongoing monitoring):
- Cluster status
- All nodes online
- Primary elected
- Replicas synced
- Replication lag < 1 second
- No errors in logs

## How to Use

**Before Restore:**
1. Print PRE_RESTORE_CHECKLIST.md
2. Go through each item
3. DO NOT start restore until all items checked
4. Keep notes for post-mortem

**During Restore:**
1. Open DURING_RESTORE_CHECKLIST.md
2. Follow along with procedures
3. Check off each item
4. Note timings for analysis

**After Restore:**
1. Run POST_RESTORE_CHECKLIST.md
2. Verify all items pass
3. Document any issues
4. Compare timings with expectations

**Ongoing:**
1. Use HEALTH_CHECK_CHECKLIST.md daily
2. Weekly health verification
3. Monthly restore drills
4. Track trends in cluster health

## Integration with Procedures

Checklists complement the step-by-step [../procedures/](../procedures/):
- Procedures explain HOW to do each step
- Checklists verify THAT each step is done correctly
- Together they ensure complete, verified restore

## Customization

Feel free to customize checklists for your environment:
- Add specific tests for your databases
- Include your application health checks
- Add your monitoring thresholds
- Document your expected timings

## Automation

Consider automating these checklists:
- Pre-restore checks: See [../scripts/pre_restore_check.sh](../scripts/pre_restore_check.sh)
- Health checks: Create monitoring alerts
- Post-restore: Generate automated reports
