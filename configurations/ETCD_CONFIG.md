# Example: etcd Configuration

Reference configuration for etcd when used as DCS (Distributed Configuration Store) with Patroni.

**Location:** `/etc/etcd/etcd.conf` or `/etc/etcd/etcd.conf.yml`

## YAML Format Configuration

```yaml
# etcd Configuration for Patroni HA Cluster

name: 'etcd-node1'
data-dir: /var/lib/etcd

# Client communication
listen-client-urls: http://0.0.0.0:2379
advertise-client-urls: http://10.0.0.1:2379

# Peer communication
listen-peer-urls: http://0.0.0.0:2380
initial-advertise-peer-urls: http://10.0.0.1:2380

# Cluster settings
initial-cluster: 'etcd-node1=http://10.0.0.1:2380,etcd-node2=http://10.0.0.2:2380,etcd-node3=http://10.0.0.3:2380'
initial-cluster-state: new
initial-cluster-token: 'etcd-cluster'

# Logging
log-level: info
logger: zap
log-outputs: [default]

# Security (optional - for production)
client-auto-tls: false
peer-auto-tls: false

# Misc
heartbeat-interval: 100
election-timeout: 1000
```

## Configuration for Each Node

### Node 1 (10.0.0.1)
```yaml
name: 'etcd-node1'
advertise-client-urls: http://10.0.0.1:2379
initial-advertise-peer-urls: http://10.0.0.1:2380
```

### Node 2 (10.0.0.2)
```yaml
name: 'etcd-node2'
advertise-client-urls: http://10.0.0.2:2379
initial-advertise-peer-urls: http://10.0.0.2:2380
```

### Node 3 (10.0.0.3)
```yaml
name: 'etcd-node3'
advertise-client-urls: http://10.0.0.3:2379
initial-advertise-peer-urls: http://10.0.0.3:2380
```

**All nodes share the same:**
- `initial-cluster` (list of all members)
- `initial-cluster-token` (cluster identifier)
- `data-dir` (path to data directory)

## Directory Preparation

```bash
# Create etcd data directory
sudo mkdir -p /var/lib/etcd
sudo chown etcd:etcd /var/lib/etcd
sudo chmod 0700 /var/lib/etcd

# Create config directory
sudo mkdir -p /etc/etcd
sudo chown etcd:etcd /etc/etcd
sudo chmod 0755 /etc/etcd

# Create log directory
sudo mkdir -p /var/log/etcd
sudo chown etcd:etcd /var/log/etcd
```

## Startup Sequence

Start etcd in this order:

```bash
# On all three nodes (in parallel or serial)
sudo systemctl start etcd

# Verify cluster health
sudo etcdctl cluster-health

# Expected output:
# member 3592a08b21e5ffc3 is healthy: got healthy result from http://10.0.0.3:2379
# member 98387c99b1ef79eb is healthy: got healthy result from http://10.0.0.2:2379
# member d282ac2d16904d1a is healthy: got healthy result from http://10.0.0.1:2379
# cluster is healthy
```

## Key Patroni Data Structure

etcd stores Patroni cluster data in this structure:

```
/service/patroni/
├── cluster_name/
│   ├── initialize        # Cluster initialization flag
│   ├── leader            # Current leader node
│   ├── members/
│   │   ├── primary       # Primary node info
│   │   ├── replica-1     # Replica-1 node info
│   │   └── replica-2     # Replica-2 node info
│   └── failover          # Failover state
```

View current state:
```bash
sudo etcdctl ls /service/patroni --recursive
```

## Production Considerations

### SSL/TLS Configuration (Recommended)

For production, enable SSL:

```yaml
# Certificates (place in /etc/etcd/certs/)
cert-file: /etc/etcd/certs/server.crt
key-file: /etc/etcd/certs/server.key
trusted-ca-file: /etc/etcd/certs/ca.crt

peer-cert-file: /etc/etcd/certs/server.crt
peer-key-file: /etc/etcd/certs/server.key
peer-trusted-ca-file: /etc/etcd/certs/ca.crt

client-cert-auth: true
peer-client-cert-auth: true
```

### Authentication (Optional)

```bash
# Enable authentication
sudo etcdctl user add root
sudo etcdctl auth enable

# Create Patroni user
sudo etcdctl user add patroni
sudo etcdctl user grant-role patroni root

# Use in Patroni config:
# etcd:
#   username: patroni
#   password: <password>
```

### Backup & Restore

```bash
# Create backup
sudo etcdctl backup --data-dir /var/lib/etcd --backup-dir /var/lib/etcd-backup

# Restore from backup
sudo systemctl stop etcd
sudo rm -rf /var/lib/etcd/*
sudo cp -r /var/lib/etcd-backup/* /var/lib/etcd/
sudo chown -R etcd:etcd /var/lib/etcd
sudo systemctl start etcd
```

## Monitoring

```bash
# Check cluster members
sudo etcdctl member list

# Check member status
sudo etcdctl member status

# View logs
sudo journalctl -u etcd -f

# Check metrics (if enabled)
curl http://localhost:2379/metrics
```

## Troubleshooting

### Cluster unhealthy
```bash
# Check each node
sudo etcdctl cluster-health

# Restart all nodes
sudo systemctl restart etcd
```

### Node can't join cluster
```bash
# Clear data directory on new node
sudo rm -rf /var/lib/etcd/*

# Reset member
sudo etcdctl member remove <member_id>
sudo systemctl restart etcd
```

### Data corruption
```bash
# Restore from backup
sudo systemctl stop etcd
sudo rm -rf /var/lib/etcd/*
sudo cp -r /var/lib/etcd-backup/* /var/lib/etcd/
sudo systemctl start etcd
```

## Performance Tuning

```yaml
# For larger clusters
heartbeat-interval: 100    # ms between heartbeats
election-timeout: 1000     # ms for election

# Snapshot settings
snapshot-count: 100000     # Number of changes before snapshot
```

## See Also

- [PATRONI_CONFIG.yml](PATRONI_CONFIG.yml) - Patroni configuration
- [../../procedures/02_STOP_PATRONI.md](../../procedures/02_STOP_PATRONI.md) - Patroni startup procedure
- [../../IMPROVEMENTS.md](../../IMPROVEMENTS.md) - Recommended enhancements
