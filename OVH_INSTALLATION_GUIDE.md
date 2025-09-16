# OVHcloud Bare Metal Installation Guide for Harvester HCI

## Overview
Step-by-step guide to install Harvester HCI on your AMD EPYC dedicated server using OVHcloud's iPXE boot feature.

## Prerequisites

### What You'll Need
- OVHcloud dedicated server (your AMD EPYC 8224P)
- Access to OVH Manager (control panel)
- Web server to host cloud-init configuration
- SSH key pair for server access

### Your Server Specs
- **CPU**: AMD EPYC 8224P (24c/48t - 2.55 GHz/3 GHz)
- **RAM**: 192 GB ECC 4800 MHz
- **Storage**: 2×960 GB + 2×1.92 TB SSD NVMe
- **Network**: Public IP + vRack capability

## Step 1: Prepare Configuration Files

### 1.1 Generate SSH Key (if needed)
```bash
# On your local machine
ssh-keygen -t rsa -b 4096 -f ~/.ssh/harvester_ovh
# This creates harvester_ovh (private) and harvester_ovh.pub (public)
```

### 1.2 Update Cloud-Init Configuration
```bash
# Edit the recommended config file
nano harvester-raid1-optimized.yaml

# Update this line with your SSH public key:
ssh_authorized_keys:
  - ssh-rsa AAAAB3NzaC1yc2E... # Replace with content from harvester_ovh.pub
```

### 1.3 Host Configuration File
You need to make the cloud-init file accessible via HTTP. Options:

**Option A: Simple HTTP Server (Testing)**
```bash
# On a machine with public IP
cd harvester-deploy/
python3 -m http.server 8080
# File will be available at: http://YOUR_IP:8080/harvester-raid1-optimized.yaml
```

**Option B: GitHub Raw (Easy)**
```bash
# Upload to GitHub and use raw URL
# Example: https://raw.githubusercontent.com/user/repo/main/harvester-raid1-optimized.yaml
```

**Option C: Web Server/CDN (Production)**
Upload to your web server or cloud storage with public HTTP access.

## Step 2: Prepare iPXE Script

### 2.1 Update iPXE Script
```bash
# Edit the iPXE script
nano harvester-ipxe-advanced.script

# Update this line with your cloud-init URL:
set cloud_init_url http://YOUR_SERVER/harvester-raid1-optimized.yaml
```

### 2.2 Complete iPXE Script Example
```ipxe
#!ipxe

echo Starting Harvester HCI automated installation...

# Network configuration
dhcp

# Harvester download URLs
set harvester_version v1.5.0
set harvester_base_url https://releases.rancher.com/harvester/${harvester_version}
set harvester_iso harvester-${harvester_version}-amd64.iso

# Your cloud-init configuration URL
set cloud_init_url http://YOUR_SERVER/harvester-raid1-optimized.yaml

echo Downloading Harvester ${harvester_version}...

# Boot parameters for automated installation
set boot_params ip=dhcp rd.live.check=0 rd.live.ram=1
set boot_params ${boot_params} harvester.install.automatic=true
set boot_params ${boot_params} harvester.install.config_url=${cloud_init_url}
set boot_params ${boot_params} console=tty1 console=ttyS0,115200n8

# Download and boot
kernel ${harvester_base_url}/${harvester_iso} ${boot_params} || goto failed
boot || goto failed

:failed
echo Boot failed, dropping to shell
shell
```

## Step 3: OVHcloud Manager Configuration

### 3.1 Access OVH Manager
1. Log into [OVH Manager](https://www.ovh.com/manager/)
2. Navigate to "Bare Metal Cloud" → "Dedicated Servers"
3. Select your server from the list

### 3.2 Configure Network Boot
1. **Go to "General Information" tab**
2. **In "Boot" section, click on the boot mode**
3. **Select "Boot on network"**
4. **Choose "iPXE Script"**

### 3.3 Upload iPXE Script
1. **Click "Add a script"**
2. **Give it a name**: `harvester-install`
3. **Paste your iPXE script content**
4. **Save the configuration**

### 3.4 Set Boot Order
1. **In "Boot" section, ensure network boot is first**
2. **Save changes**

## Step 4: Server Installation Process

### 4.1 Start Installation
1. **In OVH Manager, go to "IPMI" tab**
2. **Click "Restart" to reboot the server**
3. **Server will boot from network and start Harvester installation**

### 4.2 Monitor Installation (Optional)
```bash
# Access IPMI console through OVH Manager to watch installation
# Or wait for SSH to become available (15-30 minutes)
```

### 4.3 Monitor Progress via SSH
```bash
# Wait for installation to complete, then monitor
./harvester-monitoring.sh <SERVER_IP> ~/.ssh/harvester_ovh

# Check if SSH is available (may take 20-45 minutes)
ssh -i ~/.ssh/harvester_ovh rancher@<SERVER_IP>
```

## Step 5: Installation Verification

### 5.1 Check Server Status
```bash
# Run health check
./harvester-health-check.sh <SERVER_IP> ~/.ssh/harvester_ovh
```

### 5.2 Verify RAID Configuration
```bash
# SSH to server and check RAID
ssh -i ~/.ssh/harvester_ovh rancher@<SERVER_IP>

# Check RAID arrays
cat /proc/mdstat
mdadm --detail /dev/md0
mdadm --detail /dev/md1

# Check storage allocation
lsblk
df -h
```

### 5.3 Access Harvester UI
1. **Open browser to**: `https://<SERVER_IP>:443`
2. **Accept SSL certificate warning** (self-signed)
3. **Complete initial setup wizard**
4. **Set admin password**

## Step 6: Post-Installation Setup

### 6.1 Run Post-Install Script
```bash
./harvester-post-install.sh <SERVER_IP> ~/.ssh/harvester_ovh
```

### 6.2 Configure Storage Classes
```bash
# SSH to server
ssh -i ~/.ssh/harvester_ovh rancher@<SERVER_IP>

# Check Longhorn storage
kubectl get storageclass
kubectl get pv

# Verify storage pools
kubectl get nodes -o wide
```

## Troubleshooting Common Issues

### Issue 1: iPXE Script Not Loading
**Symptoms**: Server boots to local disk instead of network
**Solutions**:
- Verify iPXE script syntax
- Check network connectivity in IPMI console
- Ensure boot order prioritizes network boot

### Issue 2: Cloud-Init URL Not Accessible
**Symptoms**: Installation starts but doesn't complete automation
**Solutions**:
```bash
# Test URL accessibility
curl -I http://YOUR_SERVER/harvester-raid1-optimized.yaml

# Check firewall rules on hosting server
# Ensure port 80/443 is open and accessible from OVH network
```

### Issue 3: SSH Access Fails
**Symptoms**: Can't connect after installation
**Solutions**:
- Wait longer (installation can take 30-45 minutes)
- Check IPMI console for error messages
- Verify SSH key in cloud-init configuration
- Try default credentials through IPMI console

### Issue 4: RAID Arrays Not Created
**Symptoms**: Storage shows individual disks instead of RAID
**Solutions**:
```bash
# SSH to server and check
lsblk
cat /proc/mdstat

# Manually run RAID setup if needed
sudo /tmp/setup-optimized-raid.sh
```

## Network Configuration (Advanced)

### Configure vRack (Multi-Node Clusters)
1. **In OVH Manager, go to "Network" → "vRack"**
2. **Add your server to vRack**
3. **Configure private networking for cluster communication**

### Firewall Configuration
```bash
# Default ports that need to be accessible:
# 22/tcp   - SSH
# 443/tcp  - Harvester UI
# 6443/tcp - Kubernetes API (if exposing externally)
```

## Expected Timeline

### Installation Phases
- **iPXE Boot**: 2-5 minutes
- **ISO Download**: 5-10 minutes (depending on connection)
- **OS Installation**: 10-15 minutes
- **RAID Setup**: 5-10 minutes
- **Harvester Setup**: 10-20 minutes
- **First Boot**: 5-10 minutes

**Total Time**: 30-60 minutes (depending on network speed)

## Final Access Information

After successful installation:

### Access Details
- **Harvester UI**: `https://<SERVER_IP>:443`
- **SSH Access**: `ssh -i ~/.ssh/harvester_ovh rancher@<SERVER_IP>`
- **Username**: `rancher`
- **Authentication**: SSH key (configured in cloud-init)

### Storage Information
- **OS Storage**: 200GB on /dev/md0p1 (RAID1)
- **Data Storage**: 760GB on /dev/md0p2 (RAID1)
- **Bulk Storage**: 1.92TB on /dev/md1 (RAID1)
- **Total Available**: ~2.68TB distributed storage

### Next Steps
1. Create VM templates in Harvester UI
2. Configure networking and VLANs
3. Set up backup storage (optional)
4. Deploy your first VMs
5. Configure monitoring and alerting

---

**Support**: Use the troubleshooting scripts and documentation in this repository for common issues. For OVHcloud-specific problems, contact OVH support through the manager interface.