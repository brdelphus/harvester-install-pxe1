# Alternative: Boot Harvester directly via iPXE using Terraform

# Configure server for iPXE boot with Harvester
resource "ovh_dedicated_server" "harvester_pxe_boot" {
  service_name = var.server_name
  boot_script  = <<-EOT
    #!ipxe

    # Boot Harvester v1.6.0 directly
    dhcp
    kernel https://github.com/harvester/harvester/releases/download/v1.6.0/harvester-v1.6.0-vmlinuz-amd64 initrd=harvester-v1.6.0-initrd-amd64 ip=dhcp net.ifnames=1 rd.cos.disable rd.noverifyssl root=live:https://releases.rancher.com/harvester/v1.6.0/harvester-v1.6.0-rootfs-amd64.squashfs console=tty1 console=ttyS0,115200n8 harvester.install.automatic=true harvester.install.config_url=https://raw.githubusercontent.com/brdelphus/harvester-install-pxe1/refs/heads/main/harvester-config.yaml
    initrd https://github.com/harvester/harvester/releases/download/v1.6.0/harvester-v1.6.0-initrd-amd64
    boot
  EOT
  monitoring   = true
  state        = "ok"
}

# Reboot server to apply iPXE configuration
resource "ovh_dedicated_server_reboot_task" "harvester_pxe_reboot" {
  service_name = var.server_name

  keepers = [
    ovh_dedicated_server.harvester_pxe_boot.boot_script,
  ]

  depends_on = [ovh_dedicated_server.harvester_pxe_boot]
}