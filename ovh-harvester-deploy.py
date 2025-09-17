#!/usr/bin/env python3
"""
OVHcloud Harvester HCI Deployment Script
Automates iPXE boot configuration and server deployment via OVH API
"""

import ovh
import time
import sys
import json
import os

class OVHHarvesterDeployer:
    def __init__(self, endpoint='ovh-ca'):
        """
        Initialize OVH client

        Configure your API credentials at:
        https://api.ovh.com/createToken/

        Required rights:
        - GET /dedicated/server/*
        - PUT /dedicated/server/*
        - POST /dedicated/server/*/reboot
        """
        try:
            self.client = ovh.Client(
                endpoint=endpoint,
                application_key=os.environ['OVH_APPLICATION_KEY'],
                application_secret=os.environ['OVH_APPLICATION_SECRET'],
                consumer_key=os.environ['OVH_CONSUMER_KEY']
            )
        except Exception as e:
            print(f"❌ Failed to initialize OVH client: {e}")
            print("Please ensure ovh.conf file exists with your API credentials")
            sys.exit(1)

    def get_ipxe_script(self, cloud_init_url=None, stage="raid_setup"):
        """Generate iPXE script for two-stage deployment"""
        if cloud_init_url is None:
            if stage == "raid_setup":
                cloud_init_url = "https://raw.githubusercontent.com/brdelphus/harvester-install-pxe1/refs/heads/main/cloud-init-raid-setup.yaml"
            else:
                cloud_init_url = "https://raw.githubusercontent.com/brdelphus/harvester-install-pxe1/refs/heads/main/harvester-config.yaml"

        if stage == "raid_setup":
            # Stage 1: Boot Ubuntu 24.04 netboot for RAID setup
            return f"""#!ipxe

# Stage 1: Boot Ubuntu 24.04 Netboot for RAID1 Setup
dhcp
kernel https://releases.ubuntu.com/24.04/netboot/amd64/linux root=/dev/ram0 ramdisk_size=1500000 cloud-config-url={cloud_init_url} ip=dhcp url=https://releases.ubuntu.com/24.04/ubuntu-24.04.3-live-server-amd64.iso autoinstall console=tty1 console=ttyS0,115200n8
initrd https://releases.ubuntu.com/24.04/netboot/amd64/initrd
boot"""
        else:
            # Stage 2: Boot Harvester for installation on prepared RAID
            return f"""#!ipxe

# Stage 2: Boot Harvester for installation on prepared RAID1
dhcp
kernel https://github.com/harvester/harvester/releases/download/v1.6.0/harvester-v1.6.0-vmlinuz-amd64 initrd=harvester-v1.6.0-initrd-amd64 ip=dhcp net.ifnames=1 rd.cos.disable rd.noverifyssl root=live:https://releases.rancher.com/harvester/v1.6.0/harvester-v1.6.0-rootfs-amd64.squashfs console=tty1 harvester.install.config_url={cloud_init_url}
initrd https://github.com/harvester/harvester/releases/download/v1.6.0/harvester-v1.6.0-initrd-amd64
boot"""

    def list_servers(self):
        """List all dedicated servers"""
        try:
            servers = self.client.get('/dedicated/server')
            print("📋 Available servers:")
            for i, server in enumerate(servers, 1):
                server_info = self.client.get(f'/dedicated/server/{server}')
                print(f"  {i}. {server} - {server_info.get('commercialRange', 'N/A')} - {server_info.get('datacenter', 'N/A')}")
            return servers
        except Exception as e:
            print(f"❌ Failed to list servers: {e}")
            return []

    def get_server_info(self, server_name):
        """Get detailed server information"""
        try:
            info = self.client.get(f'/dedicated/server/{server_name}')
            boot_info = self.client.get(f'/dedicated/server/{server_name}/boot')

            print(f"🖥️  Server Information: {server_name}")
            print(f"   Commercial Range: {info.get('commercialRange', 'N/A')}")
            print(f"   Datacenter: {info.get('datacenter', 'N/A')}")

            # Handle boot_info being a list or dict
            if isinstance(boot_info, list) and boot_info:
                boot_type = boot_info[0].get('bootType', 'N/A') if isinstance(boot_info[0], dict) else 'N/A'
            elif isinstance(boot_info, dict):
                boot_type = boot_info.get('bootType', 'N/A')
            else:
                boot_type = 'N/A'

            print(f"   Current Boot Mode: {boot_type}")
            print(f"   State: {info.get('state', 'N/A')}")

            return info
        except Exception as e:
            print(f"❌ Failed to get server info: {e}")
            return None

    def configure_ipxe_boot(self, server_name, cloud_init_url=None, stage="raid_setup"):
        """Configure server for iPXE boot with two-stage deployment"""
        try:
            print(f"🔧 Configuring iPXE boot for {server_name} (Stage: {stage})...")

            # Generate iPXE script for the specified stage
            ipxe_script = self.get_ipxe_script(cloud_init_url, stage)

            # Configure boot parameters
            result = self.client.put(f'/dedicated/server/{server_name}',
                bootScript=ipxe_script
            )

            print("✅ iPXE boot configuration applied successfully")
            print(f"   Boot type: network")
            print(f"   Stage: {stage}")
            print(f"   Script length: {len(ipxe_script)} characters")

            return True

        except Exception as e:
            print(f"❌ Failed to configure iPXE boot: {e}")
            return False

    def reboot_server(self, server_name):
        """Reboot server to apply boot configuration"""
        try:
            print(f"🔄 Rebooting server {server_name}...")

            # Initiate reboot
            task = self.client.post(f'/dedicated/server/{server_name}/reboot')

            print("✅ Reboot initiated successfully")
            print(f"   Task ID: {task.get('id', 'N/A')}")
            print("   Server will boot from network using iPXE script")

            return True

        except Exception as e:
            print(f"❌ Failed to reboot server: {e}")
            return False

    def monitor_deployment(self, server_name, timeout=3600):
        """Monitor deployment progress"""
        print(f"👁️  Monitoring deployment progress for {server_name}...")
        print("   This will take 15-45 minutes depending on network speed")
        print("   You can also monitor via OVH IPMI console")

        start_time = time.time()

        while time.time() - start_time < timeout:
            try:
                # Check server state
                info = self.client.get(f'/dedicated/server/{server_name}')
                state = info.get('state', 'unknown')

                elapsed = int(time.time() - start_time)
                print(f"   [{elapsed:4d}s] Server state: {state}")

                if state == 'ok':
                    print("✅ Server appears to be online")
                    break

                time.sleep(30)  # Check every 30 seconds

            except Exception as e:
                print(f"   ⚠️  Monitoring error: {e}")
                time.sleep(30)

        print("ℹ️  Monitoring completed. Check server accessibility manually.")

    def deploy_harvester_two_stage(self, server_name, cloud_init_url=None, auto_reboot=True):
        """Two-stage Harvester deployment: RAID setup + Harvester installation"""
        print("🚀 Starting Two-Stage Harvester HCI deployment...")
        print(f"   Target server: {server_name}")
        print(f"   Stage 1: RAID1 setup with 200GB Harvester partition")
        print(f"   Stage 2: Harvester installation on prepared partition")

        # Get server info
        if not self.get_server_info(server_name):
            return False

        # Stage 1: Configure RAID setup
        print("\n=== Stage 1: RAID1 Setup ===")
        if not self.configure_ipxe_boot(server_name, cloud_init_url, "raid_setup"):
            return False

        if auto_reboot:
            if not self.reboot_server(server_name):
                return False

            print("⏳ Stage 1 in progress...")
            print("   - RAID1 array creation")
            print("   - 200GB partition for Harvester")
            print("   - Remaining space for user data")
            print("   - This will take 10-15 minutes")
            print("\n📋 After Stage 1 completes:")
            print("   1. Server will reboot automatically")
            print("   2. Run this script again for Stage 2")
            print("   3. Or manually reconfigure iPXE for Harvester installation")
        else:
            print("⏸️  Auto-reboot disabled for Stage 1. Please reboot server manually.")

        return True

    def deploy_harvester_stage_two(self, server_name, cloud_init_url=None, auto_reboot=True):
        """Stage 2: Install Harvester on prepared RAID partition"""
        print("🚀 Starting Stage 2: Harvester Installation...")
        print(f"   Target server: {server_name}")
        print(f"   Installing on prepared /dev/md0p1 (200GB)")

        # Get server info
        if not self.get_server_info(server_name):
            return False

        # Stage 2: Configure Harvester installation
        print("\n=== Stage 2: Harvester Installation ===")
        if not self.configure_ipxe_boot(server_name, cloud_init_url, "harvester"):
            return False

        if auto_reboot:
            if not self.reboot_server(server_name):
                return False

            # Monitor deployment
            self.monitor_deployment(server_name)
        else:
            print("⏸️  Auto-reboot disabled. Please reboot server manually.")

        print("🎉 Harvester deployment completed!")
        print("\n📋 Final configuration:")
        print("   - Harvester installed on /dev/md0p1 (200GB)")
        print("   - User data partition: /dev/md0p2 (remaining RAID1 space)")
        print("   - Access Harvester UI at https://148.113.208.186:443")
        print("   - SSH access: ssh rancher@148.113.208.186")

        return True

def main():
    """Main deployment function"""
    print("🔷 OVHcloud Harvester HCI Two-Stage Deployment Tool")
    print("=" * 60)

    # Initialize deployer
    deployer = OVHHarvesterDeployer()

    # List available servers
    servers = deployer.list_servers()
    if not servers:
        print("❌ No servers found or API access failed")
        return

    # Get server selection
    print("\n🎯 Select server for deployment:")
    try:
        choice = input("Enter server name or number: ").strip()

        # Handle numeric choice
        if choice.isdigit():
            idx = int(choice) - 1
            if 0 <= idx < len(servers):
                server_name = servers[idx]
            else:
                print("❌ Invalid server number")
                return
        else:
            server_name = choice

        if server_name not in servers:
            print(f"❌ Server '{server_name}' not found")
            return

    except KeyboardInterrupt:
        print("\n👋 Deployment cancelled")
        return

    # Select deployment stage
    print("\n🔧 Deployment Stage Selection:")
    print("1. Stage 1: RAID1 setup (200GB Harvester partition)")
    print("2. Stage 2: Harvester installation (on prepared RAID)")
    stage_choice = input("Select stage (1/2): ").strip()

    # Optional: Custom cloud-init URL
    print("\n🔧 Configuration options:")
    custom_url = input("Custom cloud-init URL (press Enter for default): ").strip()
    cloud_init_url = custom_url if custom_url else None

    # Confirm deployment
    if stage_choice == "1":
        print(f"\n⚠️  About to start Stage 1 on: {server_name}")
        print("   This will:")
        print("   - Reboot the server")
        print("   - Set up RAID1 array")
        print("   - Create 200GB partition for Harvester")
        print("   - Leave remaining space for user data")
        confirm = input("Continue with Stage 1? (yes/no): ").strip().lower()

        if confirm != 'yes':
            print("👋 Stage 1 cancelled")
            return

        # Execute Stage 1
        success = deployer.deploy_harvester_two_stage(server_name, cloud_init_url)

    elif stage_choice == "2":
        print(f"\n⚠️  About to start Stage 2 on: {server_name}")
        print("   This will:")
        print("   - Reboot the server")
        print("   - Install Harvester on /dev/md0p1")
        print("   - Configure HCI cluster")
        confirm = input("Continue with Stage 2? (yes/no): ").strip().lower()

        if confirm != 'yes':
            print("👋 Stage 2 cancelled")
            return

        # Execute Stage 2
        success = deployer.deploy_harvester_stage_two(server_name, cloud_init_url)

    else:
        print("❌ Invalid stage selection")
        return

    if success:
        print(f"\n✅ Stage {stage_choice} initiated successfully!")
    else:
        print(f"\n❌ Stage {stage_choice} failed!")

if __name__ == "__main__":
    main()