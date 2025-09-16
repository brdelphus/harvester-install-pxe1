# Harvester HCI Deployment Guide for OVHcloud Dedicated Servers

## Overview
This guide provides a complete deployment plan for Harvester HCI (Hyperconverged Infrastructure) on OVHcloud dedicated servers using custom iPXE scripts.

## Prerequisites

### Hardware Requirements
- **Minimum (Testing):**
  - 8-core CPU
  - 32GB RAM
  - 250GB SSD storage
  - 1Gbps network

- **Recommended (Production):**
  - 16+ core CPU
  - 64GB+ RAM
  - 500GB+ SSD/NVMe storage
  - 10Gbps network

### OVHcloud Requirements
- Dedicated server with IPMI/KVM access
- vRack configuration for multi-node clusters
- Anti-DDoS protection enabled

## Deployment Files

### Core Configuration Files
1. `harvester-ipxe.script` - Basic iPXE boot script
2. `harvester-ipxe-advanced.script` - Advanced iPXE with automation
3. `harvester-cloud-init.yaml` - First node configuration
4. `harvester-cluster-config.yaml` - Additional nodes configuration

### Management Scripts
1. `harvester-monitoring.sh` - Installation monitoring
2. `harvester-health-check.sh` - Cluster health verification
3. `harvester-post-install.sh` - Post-installation configuration

## Step-by-Step Deployment

### Phase 1: Pre-Deployment Setup

1. **Prepare SSH Keys**
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/harvester_key
   ```

2. **Host Cloud-Init Configuration**
   - Upload `harvester-cloud-init.yaml` to a web server
   - Update SSH public key in the configuration
   - Update the `cloud_init_url` in iPXE script

3. **Configure OVHcloud Server**
   - Access OVH Manager
   - Select your dedicated server
   - Navigate to "Boot" section
   - Choose "iPXE script" option
   - Upload `harvester-ipxe-advanced.script`

### Phase 2: Installation

1. **Deploy iPXE Script**
   ```bash
   # Upload the iPXE script to OVHcloud management interface
   # The script will automatically download and boot Harvester v1.5.0
   ```

2. **Monitor Installation**
   ```bash
   # Wait for server to complete installation (15-30 minutes)
   ./harvester-monitoring.sh <SERVER_IP> ~/.ssh/harvester_key
   ```

3. **Verify Deployment**
   ```bash
   ./harvester-health-check.sh <SERVER_IP> ~/.ssh/harvester_key
   ```

### Phase 3: Post-Installation Configuration

1. **Run Post-Install Script**
   ```bash
   ./harvester-post-install.sh <SERVER_IP> ~/.ssh/harvester_key
   ```

2. **Access Harvester UI**
   - Navigate to `https://<SERVER_IP>:443`
   - Complete initial setup wizard
   - Configure admin credentials

### Phase 4: Multi-Node Cluster (Optional)

1. **Prepare Additional Nodes**
   - Update `harvester-cluster-config.yaml` with first node details
   - Replace `{{ node_number }}` and `{{ FIRST_NODE_IP }}` placeholders
   - Get cluster token from first node

2. **Deploy Additional Nodes**
   - Use same iPXE process with updated cloud-init URL
   - Monitor join process with monitoring script

## Network Configuration

### Single Node Setup
```yaml
# Management interface (OVHcloud public)
Interface: eth0
DHCP: Enabled
Firewall: Allow 443, 6443, 22

# Storage interface (optional)
Interface: eth1 (if available)
vRack: Enabled for cluster communication
```

### Multi-Node Cluster
```yaml
# VLAN Configuration
VLAN 100: Management (Public)
VLAN 200: Storage/Cluster (vRack)
VLAN 300: VM Traffic (Isolated)

# Required Ports
443/tcp:     Harvester UI
6443/tcp:    Kubernetes API
2379-2380/tcp: etcd
10010/tcp:   Containerd metrics
```

## Storage Configuration

### Longhorn Storage
- Automatically configured during installation
- Uses available disks for distributed storage
- Configurable replicas and backup policies

### Additional Disks
```bash
# Label additional storage disks
kubectl label node <node-name> node.longhorn.io/create-default-disk=true
```

## Troubleshooting

### Common Issues

1. **iPXE Boot Failure**
   - Check network connectivity
   - Verify iPXE script syntax
   - Ensure Harvester ISO URL is accessible

2. **Installation Timeout**
   - Allow 30-45 minutes for complete installation
   - Check server hardware compatibility
   - Monitor installation logs via KVM console

3. **SSH Access Issues**
   - Verify SSH key configuration in cloud-init
   - Check if installation completed successfully
   - Use OVH KVM console for direct access

4. **UI Not Accessible**
   - Wait for all services to start (5-10 minutes post-reboot)
   - Check firewall settings
   - Verify Harvester system pods are running

### Diagnostic Commands
```bash
# Check system status
systemctl status harvester

# View installation logs
journalctl -u harvester -f

# Check Kubernetes status
kubectl get nodes
kubectl get pods -A

# Monitor resource usage
htop
df -h
```

## Security Considerations

### Network Security
- Use vRack for cluster communication
- Configure appropriate firewall rules
- Enable OVHcloud Anti-DDoS protection

### Access Control
- Use SSH keys instead of passwords
- Configure RBAC for Kubernetes access
- Implement network policies for pod isolation

### Data Protection
- Configure backup to external storage (S3)
- Enable encryption for persistent volumes
- Regular cluster backups and disaster recovery testing

## Performance Optimization

### System Tuning
```bash
# Disable swap for Kubernetes
swapoff -a

# Network optimizations
sysctl net.core.rmem_max=134217728
sysctl net.core.wmem_max=134217728

# I/O optimization for storage
echo deadline > /sys/block/sda/queue/scheduler
```

### Resource Allocation
- Reserve system resources for Harvester
- Configure appropriate resource quotas
- Monitor and adjust based on workload requirements

## Maintenance

### Regular Tasks
1. **Monitor cluster health** - Weekly health checks
2. **Update system packages** - Monthly security updates
3. **Backup configuration** - Daily automated backups
4. **Review logs** - Regular log analysis for issues

### Upgrades
- Follow Harvester upgrade documentation
- Test upgrades in non-production environment first
- Maintain backup before major upgrades

## Support and Resources

### Official Documentation
- [Harvester Documentation](https://docs.harvesterhci.io/)
- [OVHcloud Dedicated Servers](https://docs.ovh.com/gb/en/dedicated/)

### Community Resources
- [Harvester GitHub](https://github.com/harvester/harvester)
- [SUSE Rancher Community](https://forums.rancher.com/)

### Emergency Contacts
- OVHcloud Support: Available 24/7
- Harvester Community: GitHub Issues and Discussions

---

## File Checklist

Ensure you have all required files before starting deployment:

- [ ] `harvester-ipxe.script`
- [ ] `harvester-ipxe-advanced.script`
- [ ] `harvester-cloud-init.yaml`
- [ ] `harvester-cluster-config.yaml`
- [ ] `harvester-monitoring.sh`
- [ ] `harvester-health-check.sh`
- [ ] `harvester-post-install.sh`
- [ ] SSH key pair for server access
- [ ] Web server to host cloud-init files

**Note:** Update all configuration files with your specific environment details before deployment.