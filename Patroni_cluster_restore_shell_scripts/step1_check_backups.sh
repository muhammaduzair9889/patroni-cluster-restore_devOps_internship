#!/bin/bash
# DEV291 - Step 1: Check Existing Backups
# Lists all available backups in the pgBackRest repository

# List all backups in the 'demo' stanza
sudo -u postgres pgbackrest --stanza=demo info
