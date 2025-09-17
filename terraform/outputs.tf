output "server_info" {
  description = "Server information"
  value = {
    service_name = data.ovh_dedicated_server.harvester.service_name
    datacenter   = data.ovh_dedicated_server.harvester.datacenter
    state        = data.ovh_dedicated_server.harvester.state
  }
}

output "boot_configuration" {
  description = "Server boot configuration"
  value = {
    boot_type = "iPXE"
    status    = "Harvester direct boot configured"
  }
}

output "partition_layout" {
  description = "RAID1 partition layout"
  value = {
    raid1_960gb_root = "200GB ext4 / (RAID1 on 960GB disks)"
    raid1_960gb_data = "~760GB ext4 /data1 (RAID1 on 960GB disks)"
    raid1_1_9tb_data = "~1.9TB ext4 /data2 (RAID1 on 1.9TB disks)"
  }
}