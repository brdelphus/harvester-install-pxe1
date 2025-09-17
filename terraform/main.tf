# Get server information
data "ovh_dedicated_server" "harvester" {
  service_name = var.server_name
}

# Get rescue boot options
data "ovh_dedicated_server_boots" "rescue" {
  service_name = var.server_name
  boot_type    = "rescue"
}

# Get harddisk boot options
data "ovh_dedicated_server_boots" "harddisk" {
  service_name = var.server_name
  boot_type    = "harddisk"
}

# Get Ubuntu 24.04 installation template
data "ovh_dedicated_installation_template" "ubuntu_template" {
  template_name = "ubuntu2404-server_64"
}

# Install Ubuntu 24.04 with RAID1 configuration
resource "ovh_dedicated_server_reinstall_task" "harvester_install" {
  service_name      = var.server_name
  bootid_on_destroy = data.ovh_dedicated_server_boots.rescue.result[0]
  os                = data.ovh_dedicated_installation_template.ubuntu_template.template_name

  customizations {
    hostname = var.hostname
    ssh_key  = var.ssh_key
  }

  # RAID1 storage configuration - 4 disks total
  storage {
    # First RAID1: 2×960GB disks
    partitioning {
      disks = 2  # First 2 disks (960GB each)

      # Root partition - 200GB for Harvester
      layout {
        file_system = "ext4"
        mount_point = "/"
        raid_level  = 1
        size        = 204800  # 200GB in MB
      }

      # Remaining space on first RAID1 - 760GB
      layout {
        file_system = "ext4"
        mount_point = "/opt"
        raid_level  = 1
        size        = 0  # Use remaining space (~760GB)
      }
    }

    # Second RAID1: 2×1.92TB disks
    partitioning {
      disks = 2  # Second 2 disks (1.92TB each)

      # Single large partition
      layout {
        file_system = "ext4"
        mount_point = "/data"
        raid_level  = 1
        size        = 0  # Use all space (~1.92TB)
      }
    }
  }
}

# Configure server to boot from hard disk after installation
resource "ovh_dedicated_server" "harvester_config" {
  service_name = var.server_name
  boot_id      = data.ovh_dedicated_server_boots.harddisk.result[0]
  monitoring   = true
  state        = "ok"

  depends_on = [ovh_dedicated_server_reinstall_task.harvester_install]
}

# Reboot server after configuration
resource "ovh_dedicated_server_reboot_task" "harvester_reboot" {
  service_name = var.server_name

  keepers = [
    ovh_dedicated_server.harvester_config.boot_id,
  ]

  depends_on = [ovh_dedicated_server.harvester_config]
}