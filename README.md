# Harvester HCI Deployment for AMD EPYC Server

Complete deployment solution for Harvester HCI on OVHcloud dedicated servers with AMD EPYC 8224P (24c/48t), 192GB RAM, and 4x NVMe drives.

## 🚀 Quick Start

### RAID1 Configuration (Recommended)
For maximum redundancy with your 4x NVMe drives:

```bash
# 1. Upload harvester-raid1-config.yaml to web server
# 2. Update iPXE script with cloud-init URL
# 3. Deploy via OVHcloud Manager PXE boot
# 4. Monitor installation
./harvester-monitoring.sh <SERVER_IP> ~/.ssh/harvester_key

# 5. Verify deployment
./harvester-health-check.sh <SERVER_IP> ~/.ssh/harvester_key

# 6. Post-installation setup
./harvester-post-install.sh <SERVER_IP> ~/.ssh/harvester_key
```

## 📁 File Overview

### Core Deployment Files
| File | Purpose |
|------|---------|
| `harvester-raid1-config.yaml` | **MAIN CONFIG** - RAID1 setup with 960GB + 1.92TB arrays |
| `harvester-epyc-optimized.yaml` | Performance-optimized config for EPYC CPU |
| `harvester-cloud-init.yaml` | Basic single-disk configuration |
| `harvester-cluster-config.yaml` | Multi-node cluster joining configuration |

### iPXE Boot Scripts
| File | Purpose |
|------|---------|
| `harvester-ipxe.script` | Basic iPXE boot script |
| `harvester-ipxe-advanced.script` | Advanced iPXE with cloud-init automation |

### Management Scripts
| File | Purpose |
|------|---------|
| `harvester-monitoring.sh` | Monitor installation progress |
| `harvester-health-check.sh` | Comprehensive health verification |
| `harvester-post-install.sh` | Post-installation configuration |
| `raid-management-scripts.sh` | RAID1 management utilities |

### Documentation
| File | Purpose |
|------|---------|
| `RAID1_DEPLOYMENT_GUIDE.md` | **MAIN GUIDE** - Complete RAID1 deployment |
| `HARVESTER_DEPLOYMENT_GUIDE.md` | General deployment guide |
| `harvester-troubleshooting.md` | Troubleshooting and recovery |

### Storage Configurations
| File | Purpose |
|------|---------|
| `harvester-storage-config.yaml` | NVMe storage optimization |

## 🛠 Hardware Configuration

### Your Server Specs
- **CPU**: AMD EPYC 8224P (24 cores / 48 threads)
- **RAM**: 192GB ECC DDR5 4800MHz
- **Storage**: 2×960GB + 2×1.92TB SSD NVMe
- **Network**: OVHcloud dedicated with vRack support

### RAID1 Layout (Recommended)
```
RAID1 Array 1 (/dev/md0) - 960GB:
├── /dev/nvme0n1 (960GB) + /dev/nvme1n1 (960GB)
└── OS, Harvester control plane, fast workloads

RAID1 Array 2 (/dev/md1) - 1.92TB:
├── /dev/nvme2n1 (1.92TB) + /dev/nvme3n1 (1.92TB)
└── VM storage, Longhorn distributed storage
```

## 🎯 Deployment Options

### Option 1: RAID1 (Recommended)
- **File**: `harvester-raid1-config.yaml`
- **Benefits**: Hardware redundancy, fault tolerance
- **Use Case**: Production environments

### Option 2: Performance Optimized
- **File**: `harvester-epyc-optimized.yaml`
- **Benefits**: Maximum performance, no redundancy
- **Use Case**: Development, testing, high-performance workloads

### Option 3: Basic Setup
- **File**: `harvester-cloud-init.yaml`
- **Benefits**: Simple configuration
- **Use Case**: Learning, proof-of-concept

## 📋 Deployment Checklist

### Pre-Deployment
- [ ] Generate SSH key pair
- [ ] Update SSH public key in config files
- [ ] Host cloud-init YAML on web server
- [ ] Update iPXE script with cloud-init URL
- [ ] Configure OVHcloud server for PXE boot

### Deployment
- [ ] Upload iPXE script to OVH Manager
- [ ] Start server PXE boot
- [ ] Monitor installation (15-45 minutes)
- [ ] Verify SSH access
- [ ] Run health checks

### Post-Deployment
- [ ] Configure storage classes
- [ ] Set up monitoring
- [ ] Configure backup (if needed)
- [ ] Test VM deployment
- [ ] Document cluster access info

## 🔧 Management Commands

### RAID Management
```bash
# Check RAID status
./raid-management-scripts.sh status

# Monitor health
./raid-management-scripts.sh health

# Optimize performance
./raid-management-scripts.sh optimize

# Set up monitoring
./raid-management-scripts.sh setup-monitoring
```

### Harvester Management
```bash
# Health check
./harvester-health-check.sh <IP> <SSH_KEY>

# Monitor installation
./harvester-monitoring.sh <IP> <SSH_KEY>

# Post-install setup
./harvester-post-install.sh <IP> <SSH_KEY>
```

## 🌐 Access Information

After successful deployment:

- **Harvester UI**: `https://<SERVER_IP>:443`
- **SSH Access**: `ssh -i ~/.ssh/harvester_key rancher@<SERVER_IP>`
- **Default User**: `rancher` (configured via cloud-init)
- **kubectl**: Available via SSH on the server

## ⚡ Performance Expectations

With your EPYC server and RAID1 NVMe setup:

- **VM Density**: 50-100+ VMs (depending on workload)
- **Storage IOPS**: 500K+ random IOPS
- **Network**: 10Gbps+ with proper bonding
- **Memory**: Support for large memory workloads
- **CPU**: Excellent for CPU-intensive VM workloads

## 🆘 Support

### Issues and Troubleshooting
1. Check `harvester-troubleshooting.md` for common issues
2. Use diagnostic scripts for automated troubleshooting
3. Review installation logs via monitoring scripts

### Resources
- [Harvester Documentation](https://docs.harvesterhci.io/)
- [OVHcloud Support](https://www.ovhcloud.com/en/support/)
- [GitHub Issues](https://github.com/harvester/harvester/issues)

---

**Ready to Deploy**: Start with `RAID1_DEPLOYMENT_GUIDE.md` for step-by-step instructions.