# Choose deployment method by commenting/uncommenting resources

# Method 1: Install Ubuntu with RAID1 first (main.tf)
# - Installs Ubuntu 24.04 with proper RAID1 configuration
# - Creates 200GB root partition for later Harvester installation
# - Requires manual Harvester installation after Ubuntu is ready

# Method 2: Boot Harvester directly via iPXE (harvester-pxe.tf)
# - Boots Harvester v1.6.0 directly from network
# - No RAID1 configuration (Harvester doesn't support software RAID)
# - Requires manual storage configuration during Harvester setup

# To use Method 1 (Ubuntu + RAID1):
# terraform apply -target=ovh_dedicated_server_reinstall_task.harvester_install

# To use Method 2 (Direct Harvester iPXE):
# terraform apply -target=ovh_dedicated_server.harvester_pxe_boot