#!/bin/bash
# DEV291 - Failure Fix 2: Invalid Stanza Configuration
# Fixes the case-sensitive stanza name mismatch in pgbackrest.conf

# Inspect the configuration file
cat /etc/pgbackrest/pgbackrest.conf

# Open the configuration file for editing
# Change [Demo] to [demo] to match the stanza name exactly
sudo nano /etc/pgbackrest/pgbackrest.conf
# Save the file: Ctrl+O, Enter, Ctrl+X in nano

# Verify the fix
grep '\[' /etc/pgbackrest/pgbackrest.conf
