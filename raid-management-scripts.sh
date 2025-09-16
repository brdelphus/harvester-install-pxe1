#!/bin/bash

# RAID Management Scripts for Harvester EPYC Server
# Collection of utilities for managing the RAID1 arrays

# Function to check RAID status
check_raid_status() {
    echo "=== RAID Arrays Status ==="
    echo "Date: $(date)"
    echo

    if [ -f /proc/mdstat ]; then
        echo "Active RAID Arrays:"
        cat /proc/mdstat
        echo

        # Detailed status for each array
        for array in /dev/md*; do
            if [ -b "$array" ]; then
                echo "--- Detailed status for $array ---"
                mdadm --detail "$array"
                echo
            fi
        done
    else
        echo "No RAID arrays found or mdstat not available"
    fi
}

# Function to monitor RAID health
monitor_raid_health() {
    echo "=== RAID Health Monitoring ==="

    # Check for failed devices
    failed_devices=$(grep -E "F|_" /proc/mdstat | wc -l)
    if [ "$failed_devices" -gt 0 ]; then
        echo "⚠️  WARNING: Potential failed devices detected!"
        grep -E "F|_" /proc/mdstat
    else
        echo "✅ All RAID devices are healthy"
    fi

    # Check rebuild/resync status
    if grep -q "resync\|recovery\|rebuild" /proc/mdstat; then
        echo "🔄 RAID operation in progress:"
        grep -E "resync|recovery|rebuild" /proc/mdstat
    fi

    # Check NVMe drive health
    echo
    echo "=== NVMe Drive Health ==="
    for disk in nvme0n1 nvme1n1 nvme2n1 nvme3n1; do
        if [ -b "/dev/$disk" ]; then
            echo "--- /dev/$disk ---"
            if command -v smartctl >/dev/null; then
                smartctl -H "/dev/$disk" | grep -E "SMART|health"
            fi
            if command -v nvme >/dev/null; then
                nvme smart-log "/dev/$disk" | grep -E "temperature|available_spare|percentage_used"
            fi
            echo
        fi
    done
}

# Function to replace a failed drive
replace_failed_drive() {
    local array="$1"
    local failed_drive="$2"
    local replacement_drive="$3"

    if [ -z "$array" ] || [ -z "$failed_drive" ] || [ -z "$replacement_drive" ]; then
        echo "Usage: replace_failed_drive <array> <failed_drive> <replacement_drive>"
        echo "Example: replace_failed_drive /dev/md0 /dev/nvme0n1 /dev/nvme0n1"
        return 1
    fi

    echo "Replacing failed drive $failed_drive in $array with $replacement_drive"

    # Remove failed drive
    echo "Removing failed drive..."
    mdadm --manage "$array" --remove "$failed_drive"

    # Zero the replacement drive superblock
    echo "Preparing replacement drive..."
    mdadm --zero-superblock "$replacement_drive"

    # Add replacement drive
    echo "Adding replacement drive..."
    mdadm --manage "$array" --add "$replacement_drive"

    echo "Replacement initiated. Monitor with: watch cat /proc/mdstat"
}

# Function to optimize RAID performance
optimize_raid_performance() {
    echo "=== Optimizing RAID Performance ==="

    # NVMe optimizations
    for disk in nvme0n1 nvme1n1 nvme2n1 nvme3n1; do
        if [ -b "/dev/$disk" ]; then
            echo "Optimizing /dev/$disk..."

            # Set scheduler
            echo none > /sys/block/$disk/queue/scheduler 2>/dev/null || echo "Could not set scheduler for $disk"

            # Set queue depth
            echo 1024 > /sys/block/$disk/queue/nr_requests 2>/dev/null || echo "Could not set queue depth for $disk"

            # Set read-ahead
            echo 512 > /sys/block/$disk/queue/read_ahead_kb 2>/dev/null || echo "Could not set read-ahead for $disk"
        fi
    done

    # RAID array optimizations
    for array in md0 md1; do
        if [ -b "/dev/$array" ]; then
            echo "Optimizing /dev/$array..."

            # Set read-ahead
            echo 1024 > /sys/block/$array/queue/read_ahead_kb 2>/dev/null || echo "Could not set read-ahead for $array"

            # Set scheduler
            echo mq-deadline > /sys/block/$array/queue/scheduler 2>/dev/null || echo "Could not set scheduler for $array"
        fi
    done

    echo "Performance optimization completed"
}

# Function to benchmark RAID performance
benchmark_raid() {
    local test_file="/tmp/raid_benchmark"
    local test_size="1G"

    echo "=== RAID Performance Benchmark ==="
    echo "This will run I/O tests on the RAID arrays"
    echo "Test size: $test_size"
    echo

    if ! command -v fio >/dev/null; then
        echo "fio is required for benchmarking. Install with: apt install fio"
        return 1
    fi

    # Test each RAID array
    for array in md0 md1; do
        if [ -b "/dev/$array" ]; then
            echo "Testing /dev/$array..."

            # Sequential read test
            echo "Sequential Read Test:"
            fio --name=seq-read --filename="/dev/$array" --rw=read --bs=1M --size="$test_size" --numjobs=1 --runtime=30 --group_reporting --ioengine=libaio --direct=1 --readonly

            echo

            # Random read test
            echo "Random Read Test:"
            fio --name=rand-read --filename="/dev/$array" --rw=randread --bs=4k --size="$test_size" --numjobs=4 --runtime=30 --group_reporting --ioengine=libaio --direct=1 --readonly

            echo "--- End of tests for /dev/$array ---"
            echo
        fi
    done
}

# Function to backup RAID configuration
backup_raid_config() {
    local backup_dir="/etc/mdadm/backup"
    local timestamp=$(date +%Y%m%d_%H%M%S)

    echo "=== Backing up RAID Configuration ==="

    mkdir -p "$backup_dir"

    # Backup mdadm.conf
    cp /etc/mdadm/mdadm.conf "$backup_dir/mdadm.conf.$timestamp"

    # Export current configuration
    mdadm --detail --scan > "$backup_dir/mdadm_scan.$timestamp"

    # Save array details
    for array in /dev/md*; do
        if [ -b "$array" ]; then
            array_name=$(basename "$array")
            mdadm --detail "$array" > "$backup_dir/${array_name}_detail.$timestamp"
        fi
    done

    echo "RAID configuration backed up to $backup_dir"
    echo "Backup timestamp: $timestamp"
}

# Function to create performance monitoring script
create_monitoring_script() {
    cat > /usr/local/bin/raid-monitor << 'EOF'
#!/bin/bash
# Automated RAID monitoring script

LOG_FILE="/var/log/raid-monitor.log"
ALERT_EMAIL="admin@example.com"  # Change this to your email

log_message() {
    echo "$(date): $1" >> "$LOG_FILE"
}

check_failed_devices() {
    failed_count=$(grep -c "_\|F" /proc/mdstat 2>/dev/null || echo 0)
    if [ "$failed_count" -gt 0 ]; then
        message="ALERT: RAID device failure detected on $(hostname)"
        log_message "$message"
        echo "$message" | mail -s "RAID Alert" "$ALERT_EMAIL" 2>/dev/null || echo "$message"
        return 1
    fi
    return 0
}

check_sync_status() {
    if grep -q "resync\|recovery\|rebuild" /proc/mdstat; then
        message="INFO: RAID rebuild/resync in progress on $(hostname)"
        log_message "$message"
    fi
}

# Main monitoring
log_message "RAID monitoring check started"
check_failed_devices
check_sync_status
log_message "RAID monitoring check completed"
EOF

    chmod +x /usr/local/bin/raid-monitor

    # Create systemd service
    cat > /etc/systemd/system/raid-monitor.service << 'EOF'
[Unit]
Description=RAID Monitoring Service
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/raid-monitor
EOF

    # Create timer
    cat > /etc/systemd/system/raid-monitor.timer << 'EOF'
[Unit]
Description=Run RAID monitoring every 10 minutes
Requires=raid-monitor.service

[Timer]
OnCalendar=*:0/10
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable raid-monitor.timer
    systemctl start raid-monitor.timer

    echo "RAID monitoring service created and enabled"
    echo "Logs will be written to /var/log/raid-monitor.log"
}

# Main menu function
show_menu() {
    echo "============================================"
    echo "    RAID Management for Harvester EPYC     "
    echo "============================================"
    echo "1. Check RAID Status"
    echo "2. Monitor RAID Health"
    echo "3. Replace Failed Drive"
    echo "4. Optimize RAID Performance"
    echo "5. Benchmark RAID Performance"
    echo "6. Backup RAID Configuration"
    echo "7. Setup Automated Monitoring"
    echo "8. Exit"
    echo "============================================"
}

# Main script logic
case "${1:-menu}" in
    "status")
        check_raid_status
        ;;
    "health")
        monitor_raid_health
        ;;
    "replace")
        replace_failed_drive "$2" "$3" "$4"
        ;;
    "optimize")
        optimize_raid_performance
        ;;
    "benchmark")
        benchmark_raid
        ;;
    "backup")
        backup_raid_config
        ;;
    "setup-monitoring")
        create_monitoring_script
        ;;
    "menu"|*)
        while true; do
            show_menu
            read -p "Enter your choice [1-8]: " choice
            case $choice in
                1) check_raid_status ;;
                2) monitor_raid_health ;;
                3)
                    read -p "Array (e.g., /dev/md0): " array
                    read -p "Failed drive (e.g., /dev/nvme0n1): " failed
                    read -p "Replacement drive (e.g., /dev/nvme0n1): " replacement
                    replace_failed_drive "$array" "$failed" "$replacement"
                    ;;
                4) optimize_raid_performance ;;
                5) benchmark_raid ;;
                6) backup_raid_config ;;
                7) create_monitoring_script ;;
                8) echo "Goodbye!"; exit 0 ;;
                *) echo "Invalid option. Please try again." ;;
            esac
            echo
            read -p "Press Enter to continue..."
        done
        ;;
esac