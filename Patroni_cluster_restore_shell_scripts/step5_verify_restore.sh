#!/bin/bash
# DEV291 - Step 5: Verify Restored Files and Permissions
# Checks data directory contents and recovery configuration

# Check top-level directory contents
ls -la /var/lib/postgresql/15/main/

# Check the auto-generated recovery configuration
cat /var/lib/postgresql/15/main/postgresql.auto.conf
