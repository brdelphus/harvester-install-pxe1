# OVH Harvester Server Deployment with Terraform

This Terraform configuration automatically installs Ubuntu 24.04 Server on OVH dedicated server with RAID1 configuration optimized for Harvester HCI.

## RAID1 Layout

**RAID1 Array 1** (960GB disks):
- **Root**: 200GB ext4 `/` (RAID1) - OS + Harvester installation
- **Data1**: ~760GB ext4 `/data1` (RAID1) - Additional storage

**RAID1 Array 2** (1.9TB disks):
- **Data2**: ~1.9TB ext4 `/data2` (RAID1) - Main storage

## Usage

1. **Set environment variables:**
   ```bash
   source .env
   ```

2. **Initialize Terraform:**
   ```bash
   terraform init
   ```

3. **Plan deployment:**
   ```bash
   terraform plan
   ```

4. **Deploy server:**
   ```bash
   terraform apply
   ```

5. **After installation completes:**
   - SSH to server: `ssh root@148.113.208.186`
   - Harvester can be installed on the 200GB root partition

## Environment Variables

Copy `.env.example` to `.env` and configure:

- `TF_VAR_ovh_application_key` - OVH API application key
- `TF_VAR_ovh_application_secret` - OVH API application secret
- `TF_VAR_ovh_consumer_key` - OVH API consumer key
- `TF_VAR_server_name` - Server service name
- `TF_VAR_hostname` - Server hostname
- `TF_VAR_ssh_key` - SSH public key for access

## What This Does

1. Installs Ubuntu 24.04 Server on the OVH dedicated server
2. Configures RAID1 across 2 NVMe drives with custom partitioning
3. Creates dedicated 200GB partition for Harvester HCI installation
4. Sets up SSH access and hostname
5. Reboots server to complete installation

This replaces the manual iPXE approach with OVH's native server installation API.