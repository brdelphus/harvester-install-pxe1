# Quick Start Checklist for OVH Harvester Installation

## ✅ Pre-Installation Checklist

### Step 1: Prepare SSH Keys
```bash
□ ssh-keygen -t rsa -b 4096 -f ~/.ssh/harvester_ovh
□ Copy public key content from ~/.ssh/harvester_ovh.pub
```

### Step 2: Configure Cloud-Init
```bash
□ Edit harvester-raid1-optimized.yaml
□ Replace SSH key placeholder with your actual public key
□ Save the file
```

### Step 3: Host Configuration File
**Choose ONE method:**

□ **Option A - Python HTTP Server (Quick)**
```bash
cd harvester-deploy/
python3 -m http.server 8080
# URL: http://YOUR_IP:8080/harvester-raid1-optimized.yaml
```

□ **Option B - Upload to GitHub**
```bash
# Upload to GitHub repository
# Use raw URL: https://raw.githubusercontent.com/USER/REPO/main/harvester-raid1-optimized.yaml
```

□ **Option C - Your Web Server**
```bash
# Upload to your web server
# URL: https://yourserver.com/harvester-raid1-optimized.yaml
```

### Step 4: Update iPXE Script
```bash
□ Edit harvester-ipxe-advanced.script
□ Update cloud_init_url with your URL from Step 3
□ Save the file
```

## 🖥️ OVH Manager Configuration

### Step 5: Access OVH Manager
```bash
□ Login to https://www.ovh.com/manager/
□ Navigate to: Bare Metal Cloud → Dedicated Servers
□ Select your AMD EPYC server
```

### Step 6: Configure iPXE Boot
```bash
□ Click on "General Information" tab
□ In "Boot" section → Click boot mode
□ Select "Boot on network"
□ Choose "iPXE Script"
□ Click "Add a script"
□ Name: "harvester-install"
□ Paste iPXE script content
□ Save configuration
```

### Step 7: Set Boot Priority
```bash
□ Ensure "Network boot" is first priority
□ Save changes
```

## 🚀 Installation Process

### Step 8: Start Installation
```bash
□ In OVH Manager → Go to "IPMI" tab
□ Click "Restart" to reboot server
□ Monitor IPMI console (optional)
```

### Step 9: Wait for Installation
**Expected timeline: 30-60 minutes**
```bash
□ iPXE boot (2-5 min)
□ ISO download (5-10 min)
□ OS installation (10-15 min)
□ RAID setup (5-10 min)
□ Harvester setup (10-20 min)
□ First boot (5-10 min)
```

### Step 10: Monitor Progress
```bash
□ Wait for SSH to become available
□ Run: ./harvester-monitoring.sh <SERVER_IP> ~/.ssh/harvester_ovh
```

## ✅ Post-Installation Verification

### Step 11: Health Check
```bash
□ Run: ./harvester-health-check.sh <SERVER_IP> ~/.ssh/harvester_ovh
□ Verify all services are healthy
```

### Step 12: Check RAID Configuration
```bash
□ SSH: ssh -i ~/.ssh/harvester_ovh rancher@<SERVER_IP>
□ Check RAID: cat /proc/mdstat
□ Verify storage: lsblk && df -h
```

### Step 13: Access Harvester UI
```bash
□ Open browser: https://<SERVER_IP>:443
□ Accept SSL certificate warning
□ Complete setup wizard
□ Set admin password
□ Verify dashboard loads
```

### Step 14: Post-Install Configuration
```bash
□ Run: ./harvester-post-install.sh <SERVER_IP> ~/.ssh/harvester_ovh
□ Verify storage classes: kubectl get storageclass
□ Check nodes: kubectl get nodes -o wide
```

## 🎯 Success Criteria

### Installation Complete When:
```bash
□ Harvester UI is accessible at https://<SERVER_IP>:443
□ SSH access works with your key
□ RAID arrays show as healthy in /proc/mdstat
□ Storage shows ~2.68TB total capacity
□ All Kubernetes pods are running
□ Can create test VMs in Harvester UI
```

## 🆘 Quick Troubleshooting

### If Installation Fails:
```bash
□ Check IPMI console for error messages
□ Verify cloud-init URL is accessible: curl -I <YOUR_URL>
□ Confirm iPXE script syntax is correct
□ Check OVH network boot configuration
□ Try manual installation via IPMI console
```

### If SSH Fails:
```bash
□ Wait longer (can take 45+ minutes)
□ Check SSH key is correctly pasted in cloud-init
□ Try IPMI console access
□ Verify server IP address
□ Check firewall on your connection
```

### If RAID Not Working:
```bash
□ SSH to server and run: sudo /tmp/setup-optimized-raid.sh
□ Check: cat /proc/mdstat
□ Verify drives: lsblk
□ Review installation logs: journalctl -u cloud-init
```

## 📞 Support Resources

### Documentation
- `OVH_INSTALLATION_GUIDE.md` - Detailed installation guide
- `harvester-troubleshooting.md` - Common issues and solutions
- `RAID1_DEPLOYMENT_GUIDE.md` - RAID configuration details

### Scripts
- `harvester-monitoring.sh` - Monitor installation progress
- `harvester-health-check.sh` - Verify system health
- `raid-management-scripts.sh` - RAID management tools

### External Resources
- [OVH Manager](https://www.ovh.com/manager/)
- [Harvester Documentation](https://docs.harvesterhci.io/)
- [OVH Support](https://help.ovhcloud.com/)

---

**Estimated Total Time**: 1-2 hours (including preparation)
**Difficulty Level**: Intermediate
**Prerequisites**: Basic Linux CLI knowledge, OVH account access