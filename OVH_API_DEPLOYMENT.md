# OVH API Automated Harvester Deployment

## Setup Instructions

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Create OVH API Credentials

1. **Go to**: https://api.ovh.com/createToken/
2. **Select your region** (Europe, North America, etc.)
3. **Set application name**: "Harvester HCI Deployment"
4. **Set application description**: "Automated server deployment"
5. **Configure rights**:
   ```
   GET    /dedicated/server
   GET    /dedicated/server/*
   PUT    /dedicated/server/*/boot
   POST   /dedicated/server/*/reboot
   ```
6. **Generate tokens** and save them

### 3. Configure Script

Edit `ovh-harvester-deploy.py` and replace:
```python
application_key='YOUR_APPLICATION_KEY'        # From step 2
application_secret='YOUR_APPLICATION_SECRET'  # From step 2
consumer_key='YOUR_CONSUMER_KEY'             # From step 2
```

### 4. Run Deployment

```bash
python3 ovh-harvester-deploy.py
```

## What the Script Does

1. **Lists your servers** - Shows all dedicated servers
2. **Configures iPXE boot** - Sets up network boot with Harvester
3. **Reboots server** - Initiates installation process
4. **Monitors progress** - Tracks deployment status

## iPXE Script Generated

The script automatically creates this iPXE configuration:

```ipxe
#!ipxe
dhcp
set harvester_version v1.6.0
set cloud_init_url https://raw.githubusercontent.com/brdelphus/harvester-install-pxe1/refs/heads/main/harvester-raid1-optimized.yaml
kernel https://releases.rancher.com/harvester/v1.6.0/harvester-v1.6.0-amd64.iso harvester.install.automatic=true harvester.install.config_url=${cloud_init_url} console=tty1 console=ttyS0,115200n8
boot
```

## Features

- ✅ **Automated deployment** - One command setup
- ✅ **Cloud-init integration** - Uses your RAID configuration
- ✅ **Progress monitoring** - Tracks installation status
- ✅ **Error handling** - Graceful failure management
- ✅ **Server selection** - Choose from available servers
- ✅ **Custom configurations** - Override cloud-init URL

## Timeline

- **API configuration**: 1-2 minutes
- **Server reboot**: 2-3 minutes
- **ISO download**: 5-15 minutes
- **Installation**: 15-30 minutes
- **Total time**: 25-50 minutes

## Troubleshooting

### API Authentication Errors
- Verify credentials are correct
- Check API rights are properly configured
- Ensure consumer key is validated

### Boot Configuration Fails
- Check server supports network boot
- Verify server is in correct state
- Try manual reboot via OVH Manager

### Installation Issues
- Monitor via OVH IPMI console
- Check cloud-init URL accessibility
- Verify Harvester ISO download

## Manual Verification

After running the script, you can verify via OVH API:

```bash
# Check boot configuration
curl -X GET "https://api.ovh.com/1.0/dedicated/server/YOUR_SERVER/boot" \
  -H "X-Ovh-Application: YOUR_APP_KEY" \
  -H "X-Ovh-Consumer: YOUR_CONSUMER_KEY"

# Check server status
curl -X GET "https://api.ovh.com/1.0/dedicated/server/YOUR_SERVER" \
  -H "X-Ovh-Application: YOUR_APP_KEY" \
  -H "X-Ovh-Consumer: YOUR_CONSUMER_KEY"
```

## Success Indicators

- ✅ Server boots from network
- ✅ Harvester ISO downloads successfully
- ✅ Cloud-init configuration applied
- ✅ RAID arrays created automatically
- ✅ Harvester UI accessible at https://server-ip:443
- ✅ SSH access works with configured key

---

**Note**: This script automates the entire iPXE deployment process that OVH removed from their web interface. It provides the same functionality with better automation and monitoring capabilities.