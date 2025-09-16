#!/usr/bin/env python3
"""
OVHcloud Harvester HCI Deployment Script
Automates iPXE boot configuration and server deployment via OVH API
"""

import ovh
import time
import sys
import json

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
                config_file='./ovh.conf'
            )
        except Exception as e:
            print(f"❌ Failed to initialize OVH client: {e}")
            print("Please ensure ovh.conf file exists with your API credentials")
            sys.exit(1)

    def get_ipxe_script(self, cloud_init_url=None):
        """Generate iPXE script for Harvester deployment"""
        if cloud_init_url is None:
            cloud_init_url = "https://raw.githubusercontent.com/brdelphus/harvester-install-pxe1/refs/heads/main/harvester-raid1-optimized.yaml"

        # Follow working example pattern: GitHub for kernel/initrd, Rancher CDN for rootfs
        return f"""#!ipxe

dhcp
kernel https://github.com/harvester/harvester/releases/download/v1.6.0/harvester-v1.6.0-vmlinuz-amd64 initrd=harvester-v1.6.0-initrd-amd64 ip=dhcp net.ifnames=1 rd.cos.disable rd.noverifyssl root=live:https://releases.rancher.com/harvester/v1.6.0/harvester-v1.6.0-rootfs-amd64.squashfs console=tty1 harvester.install.automatic=true harvester.install.config_url={cloud_init_url}
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

    def configure_ipxe_boot(self, server_name, cloud_init_url=None):
        """Configure server for iPXE boot with Harvester"""
        try:
            print(f"🔧 Configuring iPXE boot for {server_name}...")

            # Generate iPXE script
            ipxe_script = self.get_ipxe_script(cloud_init_url)

            # Configure boot parameters
            result = self.client.put(f'/dedicated/server/{server_name}',
                bootScript=ipxe_script
            )

            print("✅ iPXE boot configuration applied successfully")
            print(f"   Boot type: network")
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

    def deploy_harvester(self, server_name, cloud_init_url=None, auto_reboot=True):
        """Complete Harvester deployment process"""
        print("🚀 Starting Harvester HCI deployment...")
        print(f"   Target server: {server_name}")
        print(f"   Cloud-init URL: {cloud_init_url or 'default'}")

        # Get server info
        if not self.get_server_info(server_name):
            return False

        # Configure iPXE boot
        if not self.configure_ipxe_boot(server_name, cloud_init_url):
            return False

        # Reboot server
        if auto_reboot:
            if not self.reboot_server(server_name):
                return False

            # Monitor deployment
            self.monitor_deployment(server_name)
        else:
            print("⏸️  Auto-reboot disabled. Please reboot server manually.")

        print("🎉 Deployment process completed!")
        print("\n📋 Next steps:")
        print("   1. Monitor installation via OVH IPMI console")
        print("   2. Wait 15-45 minutes for installation to complete")
        print("   3. Access Harvester UI at https://<server-ip>:443")
        print("   4. SSH access: ssh -i ~/.ssh/harvester_key rancher@<server-ip>")

        return True

def main():
    """Main deployment function"""
    print("🔷 OVHcloud Harvester HCI Deployment Tool")
    print("=" * 50)

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

    # Optional: Custom cloud-init URL
    print("\n🔧 Configuration options:")
    custom_url = input("Custom cloud-init URL (press Enter for default): ").strip()
    cloud_init_url = custom_url if custom_url else None

    # Confirm deployment
    print(f"\n⚠️  About to deploy Harvester on: {server_name}")
    print("   This will reboot the server and install Harvester HCI")
    confirm = input("Continue? (yes/no): ").strip().lower()

    if confirm != 'yes':
        print("👋 Deployment cancelled")
        return

    # Execute deployment
    success = deployer.deploy_harvester(server_name, cloud_init_url)

    if success:
        print("\n✅ Deployment initiated successfully!")
    else:
        print("\n❌ Deployment failed!")

if __name__ == "__main__":
    main()