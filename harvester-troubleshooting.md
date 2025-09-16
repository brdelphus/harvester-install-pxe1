# Harvester Troubleshooting Guide

## Common Issues and Solutions

### 1. iPXE Boot Issues

#### Problem: iPXE script fails to download ISO
**Symptoms:**
- Server boots but hangs at iPXE download
- Network timeout errors
- "Failed to boot Harvester ISO" message

**Solutions:**
```bash
# Check network connectivity
ping 8.8.8.8

# Verify Harvester ISO URL accessibility
curl -I https://releases.rancher.com/harvester/v1.5.0/harvester-v1.5.0-amd64.iso

# Test alternative download sources
# Update iPXE script with mirror URLs if needed
```

#### Problem: iPXE syntax errors
**Symptoms:**
- "Script error" during boot
- iPXE command not recognized

**Solutions:**
1. Validate iPXE script syntax
2. Remove any non-ASCII characters
3. Ensure proper line endings (Unix format)
4. Test script with iPXE emulator first

### 2. Installation Issues

#### Problem: Installation hangs or fails
**Symptoms:**
- Installation process stops at specific stage
- No progress for extended period (>45 minutes)
- Error messages in console

**Diagnostic Steps:**
```bash
# Access OVH KVM console to view installation logs
# Check system resources during installation
top
free -h
df -h

# Monitor installation logs
tail -f /var/log/messages
journalctl -f
```

**Solutions:**
1. Verify hardware compatibility
2. Check available disk space (minimum 250GB)
3. Ensure sufficient RAM (minimum 32GB)
4. Verify BIOS virtualization settings are enabled

#### Problem: Cloud-init configuration not applied
**Symptoms:**
- SSH access fails with configured keys
- Hostname not set correctly
- Services not configured as expected

**Solutions:**
```bash
# Check cloud-init status
cloud-init status

# View cloud-init logs
cat /var/log/cloud-init.log
cat /var/log/cloud-init-output.log

# Verify cloud-init configuration
cloud-init query userdata

# Re-run cloud-init if needed
cloud-init clean
cloud-init init
```

### 3. Network Configuration Issues

#### Problem: Management interface not accessible
**Symptoms:**
- Cannot reach Harvester UI at https://server-ip:443
- SSH connection fails
- Network services not responding

**Diagnostic Commands:**
```bash
# Check network interfaces
ip addr show
ip route show

# Test network connectivity
ping <gateway-ip>
ping 8.8.8.8

# Check service status
systemctl status networking
systemctl status harvester

# Verify firewall rules
iptables -L
ufw status
```

**Solutions:**
1. Verify network cable connections
2. Check DHCP configuration
3. Validate OVHcloud network settings
4. Restart networking services if needed

#### Problem: Cluster nodes cannot communicate
**Symptoms:**
- Additional nodes fail to join cluster
- Intermittent connectivity between nodes
- vRack network issues

**Solutions:**
```bash
# Check vRack configuration in OVH Manager
# Verify VLAN settings

# Test inter-node connectivity
ping <other-node-ip>
telnet <other-node-ip> 6443

# Check cluster network configuration
kubectl get nodes -o wide
kubectl describe node <node-name>
```

### 4. Storage Issues

#### Problem: Longhorn storage not working
**Symptoms:**
- Persistent volumes stuck in pending state
- Storage class not available
- Disk attachment failures

**Diagnostic Commands:**
```bash
# Check Longhorn system status
kubectl get pods -n longhorn-system
kubectl get storageclass

# Check disk status
lsblk
fdisk -l

# View Longhorn logs
kubectl logs -n longhorn-system <longhorn-pod-name>
```

**Solutions:**
```bash
# Restart Longhorn components
kubectl rollout restart deployment/longhorn-ui -n longhorn-system
kubectl rollout restart daemonset/longhorn-manager -n longhorn-system

# Check disk formatting and partitioning
# Ensure disks are not mounted elsewhere
umount /dev/sdb1  # example

# Verify node labels for storage
kubectl get nodes --show-labels | grep storage
```

### 5. Kubernetes API Issues

#### Problem: kubectl commands fail
**Symptoms:**
- "connection refused" errors
- API server not responding
- Certificate errors

**Diagnostic Steps:**
```bash
# Check API server status
systemctl status k3s || systemctl status rke2-server

# Verify certificates
ls -la /etc/rancher/k3s/
ls -la /etc/rancher/rke2/

# Check API server logs
journalctl -u k3s -f
journalctl -u rke2-server -f
```

**Solutions:**
```bash
# Restart Kubernetes services
systemctl restart k3s
# or
systemctl restart rke2-server

# Reset kubeconfig
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
# or
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

# Verify cluster connectivity
kubectl cluster-info
kubectl get nodes
```

### 6. Service Access Issues

#### Problem: Harvester UI not accessible
**Symptoms:**
- Browser shows connection timeout
- SSL certificate errors
- Service unavailable errors

**Solutions:**
```bash
# Check Harvester UI service
kubectl get svc -n harvester-system
kubectl get pods -n harvester-system | grep ui

# Verify ingress configuration
kubectl get ingress -A

# Check for port conflicts
netstat -tulpn | grep :443
ss -tulpn | grep :443

# Restart Harvester UI
kubectl rollout restart deployment/harvester -n harvester-system
```

### 7. Performance Issues

#### Problem: Slow performance or high resource usage
**Symptoms:**
- High CPU or memory usage
- Slow response times
- Timeouts during operations

**Diagnostic Commands:**
```bash
# Monitor resource usage
top
htop
iotop

# Check disk I/O
iostat -x 1

# Monitor network traffic
iftop
nethogs

# Check system load
uptime
vmstat 1

# View resource allocation
kubectl top nodes
kubectl top pods -A
```

**Solutions:**
```bash
# Optimize system parameters
echo 'vm.swappiness=1' >> /etc/sysctl.conf
echo 'net.core.rmem_max=134217728' >> /etc/sysctl.conf
sysctl -p

# Check for resource limits
kubectl describe node <node-name>

# Scale down non-essential workloads
kubectl scale deployment <deployment-name> --replicas=1
```

### 8. Update and Upgrade Issues

#### Problem: Harvester upgrade fails
**Symptoms:**
- Upgrade process hangs
- Services fail to start after upgrade
- Compatibility issues

**Pre-upgrade Checklist:**
```bash
# Backup cluster configuration
kubectl get all -A -o yaml > cluster-backup.yaml

# Check cluster health
./harvester-health-check.sh <server-ip>

# Verify disk space
df -h

# Document current version
kubectl get nodes -o wide
```

**Recovery Steps:**
```bash
# Check upgrade status
kubectl get harvesterupgrade -A

# View upgrade logs
kubectl logs -n harvester-system <upgrade-pod>

# Rollback if necessary (follow Harvester documentation)
```

## Emergency Recovery Procedures

### Complete System Recovery

If the system becomes completely unresponsive:

1. **Access via OVH KVM Console**
   - Log into OVH Manager
   - Access server KVM/IPMI
   - Boot from rescue mode if needed

2. **Backup Critical Data**
   ```bash
   # Mount disks in rescue mode
   mkdir /mnt/system
   mount /dev/sda1 /mnt/system

   # Backup configurations
   cp -r /mnt/system/etc/rancher /backup/
   cp -r /mnt/system/var/lib/rancher /backup/
   ```

3. **Reinstall Harvester**
   - Use iPXE script to reinstall
   - Restore configurations from backup
   - Rejoin cluster if multi-node setup

### Data Recovery

For storage-related emergencies:

```bash
# Check Longhorn backup status
kubectl get backupvolumes -A

# Restore from backup
kubectl apply -f backup-restore.yaml

# Manual data recovery from underlying storage
mount /dev/sdb1 /mnt/recover
find /mnt/recover -name "*.backup" -type f
```

## Monitoring and Alerting

### Health Check Automation

Create automated health monitoring:

```bash
# Add to crontab for regular health checks
*/15 * * * * /root/harvester-health-check.sh <server-ip> 2>&1 | logger -t harvester-health

# Set up alerts for critical issues
# Configure with your monitoring system (Prometheus, etc.)
```

### Log Aggregation

Centralize log collection:

```bash
# Configure rsyslog for remote logging
echo "*.* @@log-server:514" >> /etc/rsyslog.conf
systemctl restart rsyslog

# Set up log rotation
cat > /etc/logrotate.d/harvester << EOF
/var/log/harvester.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
EOF
```

## Getting Help

### Information to Gather Before Seeking Support

1. **System Information**
   ```bash
   uname -a
   lsb_release -a
   kubectl version
   ```

2. **Hardware Details**
   ```bash
   lscpu
   free -h
   lsblk
   lspci
   ```

3. **Network Configuration**
   ```bash
   ip addr show
   ip route show
   systemctl status networking
   ```

4. **Service Status**
   ```bash
   systemctl status harvester
   kubectl get nodes -o wide
   kubectl get pods -A
   ```

5. **Recent Logs**
   ```bash
   journalctl -u harvester --since "1 hour ago"
   kubectl logs -n harvester-system --tail=100
   ```

### Support Channels

- **Harvester GitHub Issues:** https://github.com/harvester/harvester/issues
- **SUSE Community:** https://forums.rancher.com/
- **OVHcloud Support:** Available through OVH Manager
- **Documentation:** https://docs.harvesterhci.io/

### Creating Support Tickets

Include the following information:
- Harvester version and installation method
- OVHcloud server specifications
- Network configuration details
- Error messages and log excerpts
- Steps to reproduce the issue
- Timeline of events leading to the problem