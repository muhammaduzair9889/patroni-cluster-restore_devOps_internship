#!/bin/bash
# DEV291 - Step 4: Run the pgBackRest Restore Command
# Restores the most recent backup to the cleaned data directory

# Run the restore — this will take several minutes depending on backup size
sudo -u postgres pgbackrest --stanza=demo \
  --delta restore
