# Failure 2: Stanza Configuration Mismatch

**Status:** RESOLVED

**Severity:** HIGH (Blocks restore immediately)

**Time to Resolve:** 1 minute

## Failure Description

**Error Message:**
```
ERROR: stanza 'demo' not found in pgbackrest.conf
```

**When It Occurs:**
During Step 1 (Check Backups) or Step 4 (Run Restore)

**Initial Symptom:**
```bash
sudo -u postgres pgbackrest info --stanza=demo
ERROR: stanza 'demo' not found in '/etc/pgbackrest/pgbackrest.conf'
```

## Root Cause Analysis

**The Mismatch:**
```bash
# In /etc/pgbackrest/pgbackrest.conf:
[Demo]    ← Uppercase D

# But command uses:
pgbackrest info --stanza=demo    ← Lowercase d

# Result: pgBackRest looks for [demo], can't find [Demo]
# ERROR: Stanza not found
```

**Why This Happens:**
```
Stanza names in pgBackRest are CASE-SENSITIVE
├─ [demo] ≠ [Demo] ≠ [DEMO]
├─ All different stanzas from pgBackRest's perspective
└─ Configuration must match EXACTLY

Common mistake:
├─ Config created with uppercase: [Demo]
├─ Operators use lowercase: --stanza=demo
├─ pgBackRest expects exact match
└─ ERROR
```

## Solution

### Immediate Fix (1 minute)

**Option 1: Change config to lowercase (Recommended)**

```bash
# Edit config
sudo nano /etc/pgbackrest/pgbackrest.conf

# Find: [Demo]
# Change to: [demo]

# Verify change
sudo cat /etc/pgbackrest/pgbackrest.conf | grep -i stanza
# Should show: [demo] (lowercase)

# Retry command
sudo -u postgres pgbackrest info --stanza=demo
```

**Option 2: Change command to uppercase**

```bash
# Use uppercase in commands
sudo -u postgres pgbackrest info --stanza=Demo

# But NOT RECOMMENDED - inconsistent with best practices
```

## Prevention

### Configuration Best Practice

**Always use lowercase stanza names:**

```ini
# GOOD (lowercase):
[demo]
[prod]
[staging]

# BAD (mixed case):
[Demo]
[Prod]
[Staging]

# BAD (uppercase):
[DEMO]
[PROD]
[STAGING]
```

### Pre-Restore Checklist

```
[ ] Verify stanza name is lowercase in config:
    grep "^\[" /etc/pgbackrest/pgbackrest.conf
    Expected: [demo] (lowercase)

[ ] Verify stanza name matches in commands:
    --stanza=demo (lowercase)
    
[ ] Test: pgbackrest info --stanza=demo
    Should NOT error with "stanza not found"
```

## Detection

**Automated detection:**
```bash
# Check if stanza config is lowercase
CONFIG_STANZA=$(sudo grep "^\[" /etc/pgbackrest/pgbackrest.conf | tr -d '[]')
if [ "$CONFIG_STANZA" != "${CONFIG_STANZA,,}" ]; then
  echo "ERROR: Stanza name is not lowercase: $CONFIG_STANZA"
  echo "Fix: Change to [${CONFIG_STANZA,,}] in pgbackrest.conf"
  exit 1
fi
```

## Real-World Impact

**This failure occurs:**
1. First time admin sets up pgBackRest (new config)
2. After config is edited (changes made)
3. When copying config from another system (format differences)

**Example timeline:**
```
T+0:    Admin creates pgbackrest.conf with [Demo]
        └─ Looks good to human eye
        
T+1d:   Admin tries: pgbackrest info
        └─ SUCCESS (finds [Demo])
        
T+5d:   Different admin runs: pgbackrest info --stanza=demo
        └─ ERROR: stanza not found
        └─ Puzzled: "I thought backups were working?"
        
T+6d:   Realizes case mismatch
        └─ Changes to lowercase
        └─ All tests pass
```

## Similar Issues

**Case sensitivity in other commands:**
```bash
# All these are DIFFERENT:
pgbackrest info --stanza=demo
pgbackrest info --stanza=Demo
pgbackrest info --stanza=DEMO

# Only one will work (the one matching config)
```

## Related Documentation

- Step 1: [../procedures/01_CHECK_BACKUPS.md](../procedures/01_CHECK_BACKUPS.md#17-verify-stanza-configuration)
- Configuration: [../configurations/PGBACKREST_CONFIG.conf](../configurations/PGBACKREST_CONFIG.conf)
- Terminology: [../docs/TERMINOLOGY.md#stanza](../docs/TERMINOLOGY.md)

## Key Lessons

1. **Case matters** - Stanza names are case-sensitive
2. **Standards help** - Use lowercase consistently
3. **Test early** - Verify config works before production
4. **Documentation** - Document your stanza naming convention
5. **Automation detects** - Include in health checks

## Automation

```bash
#!/bin/bash
# Pre-restore check for stanza name

set -e

CONFIG="/etc/pgbackrest/pgbackrest.conf"
STANZA=$(grep "^\[" "$CONFIG" | sed 's/\[//g' | sed 's/\]//g' | head -1)

if [ -z "$STANZA" ]; then
  echo "ERROR: No stanza found in $CONFIG"
  exit 1
fi

echo "Found stanza: $STANZA"

# Test the stanza
sudo -u postgres pgbackrest info --stanza="$STANZA"

echo "✓ Stanza configuration is valid"
```
