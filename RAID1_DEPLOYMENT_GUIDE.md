# Harvester RAID1 Deployment Guide for AMD EPYC Server

## Overview
This guide configures software RAID1 on your AMD EPYC 8224P server with 4x NVMe drives for maximum redundancy and performance.

## RAID Configuration

### Storage Layout
```
RAID1 Array 1 (/dev/md0) - 960GB:
├── /dev/nvme0n1 (960GB SSD NVMe)
└── /dev/nvme1n1 (960GB SSD NVMe)
└── Purpose: OS, Harvester control plane, fast workloads

RAID1 Array 2 (/dev/md1) - 1.92TB:
├── /dev/nvme2n1 (1.92TB SSD NVMe)
└── /dev/nvme3n1 (1.92TB SSD NVMe)
└── Purpose: VM storage, Longhorn distributed storage
```

### Benefits of RAID1 Setup
- **Redundancy**: Each array can survive one drive failure
- **Performance**: Read performance improvement with dual drives
- **Reliability**: Hardware-level fault tolerance
- **Simplicity**: Easy management and recovery

## Deployment Files

### Core Configuration
- `harvester-raid1-config.yaml` - Main deployment configuration
- `raid-management-scripts.sh` - RAID management utilities

### Key Features
1. **Automatic RAID Setup** - Creates arrays during installation
2. **Performance Optimization** - NVMe-specific tuning
3. **Health Monitoring** - Automated RAID status monitoring
4. **Recovery Tools** - Drive replacement and backup utilities

## Step-by-Step Deployment

### Phase 1: Pre-Deployment

1. **Update iPXE Script**
   ```bash
   # Edit harvester-ipxe-advanced.script
   # Update cloud_init_url to point to harvester-raid1-config.yaml
   ```

2. **Host Configuration Files**
   - Upload `harvester-raid1-config.yaml` to web server
   - Update SSH public key in configuration
   - Verify URL accessibility

### Phase 2: Installation

1. **Deploy via OVHcloud Manager**
   - Upload iPXE script
   - Set server to PXE boot
   - Start installation

2. **RAID Array Creation** (Automatic)
   ```bash
   # The installation will automatically:
   # - Create /dev/md0 (960GB RAID1) for OS
   # - Create /dev/md1 (1.92TB RAID1) for storage
   # - Configure mdadm.conf
   # - Optimize performance settings
   ```

3. **Monitor Installation**
   ```bash
   ./harvester-monitoring.sh <SERVER_IP> ~/.ssh/harvester_key
   ```

### Phase 3: Verification

1. **Check RAID Status**
   ```bash
   # SSH to server and run:
   cat /proc/mdstat
   mdadm --detail /dev/md0
   mdadm --detail /dev/md1
   ```

2. **Verify Harvester**
   ```bash
   ./harvester-health-check.sh <SERVER_IP> ~/.ssh/harvester_key
   ```

## RAID Management

### Daily Operations

1. **Check RAID Health**
   ```bash
   ./raid-management-scripts.sh health
   ```

2. **Monitor Performance**
   ```bash
   ./raid-management-scripts.sh benchmark
   ```

3. **View Status**
   ```bash
   ./raid-management-scripts.sh status
   ```

### Drive Replacement Procedure

If a drive fails:

1. **Identify Failed Drive**
   ```bash
   cat /proc/mdstat
   # Look for (F) next to failed drives
   ```

2. **Replace Drive** (Hot-swappable)
   ```bash
   ./raid-management-scripts.sh replace /dev/md0 /dev/nvme0n1 /dev/nvme0n1
   ```

3. **Monitor Rebuild**
   ```bash
   watch cat /proc/mdstat
   # Rebuild typically takes 30-60 minutes for 960GB
   # Rebuild typically takes 60-120 minutes for 1.92TB
   ```

### Performance Optimization

The configuration includes automatic optimizations:

```bash
# NVMe-specific settings
- I/O Scheduler: none (optimal for NVMe)
- Queue Depth: 1024
- Read-ahead: 512KB per drive, 1024KB per array

# RAID1-specific settings
- Write-intent bitmap: Enabled for faster recovery
- Chunk size: N/A (RAID1 mirrors data)
- Stripe cache: Optimized for NVMe latency
```

### Storage Classes

Longhorn storage classes are automatically configured:

1. **longhorn-raid1** (Default)
   - Single replica (RAID1 provides redundancy)
   - Strict local scheduling
   - Optimal for most workloads

2. **longhorn-raid1-replicated**
   - Double redundancy (RAID1 + Longhorn)
   - Best-effort scheduling
   - Critical data protection

## Monitoring and Alerting

### Automated Monitoring

The system includes automated RAID monitoring:

```bash
# Enable automatic monitoring
./raid-management-scripts.sh setup-monitoring

# Check logs
tail -f /var/log/raid-monitor.log
```

### Manual Health Checks

```bash
# Quick status check
cat /proc/mdstat

# Detailed health report
./raid-management-scripts.sh health

# Drive SMART data
smartctl -a /dev/nvme0n1
nvme smart-log /dev/nvme0n1
```

## Troubleshooting

### Common Issues

1. **Array Won't Start**
   ```bash
   # Check for existing superblocks
   mdadm --examine /dev/nvme*

   # Force assembly if needed
   mdadm --assemble --force /dev/md0 /dev/nvme0n1 /dev/nvme1n1
   ```

2. **Degraded Array**
   ```bash
   # Check which drive failed
   mdadm --detail /dev/md0

   # Remove failed drive
   mdadm --manage /dev/md0 --remove /dev/nvme0n1

   # Add replacement
   mdadm --manage /dev/md0 --add /dev/nvme0n1
   ```

3. **Performance Issues**
   ```bash
   # Re-run optimization
   ./raid-management-scripts.sh optimize

   # Check for rebuild activity
   cat /proc/mdstat
   ```

### Recovery Procedures

1. **Backup RAID Configuration**
   ```bash
   ./raid-management-scripts.sh backup
   ```

2. **Emergency Array Recovery**
   ```bash
   # Stop array
   mdadm --stop /dev/md0

   # Examine drives
   mdadm --examine /dev/nvme0n1 /dev/nvme1n1

   # Rebuild from surviving drive
   mdadm --create /dev/md0 --level=1 --raid-devices=2 \
     --assume-clean /dev/nvme0n1 missing
   ```

## Performance Expectations

### Expected Performance (RAID1)
- **Sequential Read**: ~6,000 MB/s (combined from both drives)
- **Sequential Write**: ~3,000 MB/s (limited by single write)
- **Random Read IOPS**: ~800,000 IOPS (combined)
- **Random Write IOPS**: ~400,000 IOPS (single drive performance)

### Capacity
- **Usable Space**: 960GB + 1.92TB = ~2.88TB total
- **Redundancy**: Can lose one drive per array without data loss
- **Efficiency**: 50% storage efficiency (typical for RAID1)

## Maintenance Schedule

### Daily
- Automated RAID health checks
- Performance monitoring
- Log review

### Weekly
- Manual RAID status verification
- Drive health assessment (SMART data)
- Performance benchmarking

### Monthly
- RAID configuration backup
- Firmware updates (if available)
- Capacity planning review

### Quarterly
- Disaster recovery testing
- Drive replacement testing
- Performance optimization review

## Emergency Contacts

- **OVHcloud Support**: 24/7 hardware replacement
- **RAID Issues**: Use raid-management-scripts.sh for diagnostics
- **Harvester Issues**: Standard Harvester troubleshooting procedures

---

**Note**: This RAID1 configuration provides excellent redundancy and performance for Harvester HCI workloads. The dual NVMe arrays ensure both system and storage resilience while maintaining high performance characteristics.