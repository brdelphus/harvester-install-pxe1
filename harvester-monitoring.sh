#!/bin/bash

# Harvester Installation Monitoring Script
# Use this to monitor the installation progress on OVHcloud servers

SERVER_IP="${1:-}"
SSH_KEY="${2:-~/.ssh/id_rsa}"
LOG_FILE="harvester-install-$(date +%Y%m%d-%H%M%S).log"

if [ -z "$SERVER_IP" ]; then
    echo "Usage: $0 <server_ip> [ssh_key_path]"
    echo "Example: $0 1.2.3.4 ~/.ssh/id_rsa"
    exit 1
fi

echo "Monitoring Harvester installation on $SERVER_IP"
echo "Log file: $LOG_FILE"

# Function to check server connectivity
check_connectivity() {
    echo "Checking server connectivity..."
    if ping -c 3 "$SERVER_IP" >/dev/null 2>&1; then
        echo "✓ Server is reachable"
        return 0
    else
        echo "✗ Server is not reachable"
        return 1
    fi
}

# Function to monitor SSH availability
monitor_ssh() {
    echo "Waiting for SSH to become available..."
    local max_attempts=60
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i "$SSH_KEY" rancher@"$SERVER_IP" "echo 'SSH Ready'" >/dev/null 2>&1; then
            echo "✓ SSH is available (attempt $attempt)"
            return 0
        fi
        echo "Attempt $attempt/$max_attempts - SSH not ready yet..."
        sleep 30
        ((attempt++))
    done

    echo "✗ SSH did not become available within timeout"
    return 1
}

# Function to monitor installation progress
monitor_installation() {
    echo "Monitoring Harvester installation progress..."

    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" rancher@"$SERVER_IP" '
        echo "=== System Information ==="
        hostname
        uptime
        free -h
        df -h

        echo -e "\n=== Network Configuration ==="
        ip addr show

        echo -e "\n=== Harvester Services ==="
        sudo systemctl status harvester --no-pager || echo "Harvester service not yet available"

        echo -e "\n=== Harvester Logs ==="
        sudo journalctl -u harvester --no-pager -n 50 || echo "No Harvester logs yet"

        echo -e "\n=== Installation Logs ==="
        if [ -f /var/log/harvester-setup.log ]; then
            tail -20 /var/log/harvester-setup.log
        else
            echo "Installation log not yet available"
        fi

        echo -e "\n=== Kubernetes Status ==="
        if command -v kubectl >/dev/null 2>&1; then
            kubectl get nodes -o wide || echo "Kubernetes not ready yet"
            kubectl get pods -A || echo "No pods running yet"
        else
            echo "kubectl not available yet"
        fi

        echo -e "\n=== Process Status ==="
        ps aux | grep -E "(rancher|k3s|rke2|harvester)" | grep -v grep
    ' | tee -a "$LOG_FILE"
}

# Function to check cluster health
check_cluster_health() {
    echo "Checking Harvester cluster health..."

    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" rancher@"$SERVER_IP" '
        echo "=== Cluster Health Check ==="

        # Check if Harvester UI is accessible
        if curl -k -s https://localhost:443 >/dev/null 2>&1; then
            echo "✓ Harvester UI is accessible"
        else
            echo "✗ Harvester UI is not accessible"
        fi

        # Check node status
        if kubectl get nodes >/dev/null 2>&1; then
            echo "✓ Kubernetes API is responsive"
            kubectl get nodes
        else
            echo "✗ Kubernetes API is not responsive"
        fi

        # Check storage
        if kubectl get longhorn-system >/dev/null 2>&1; then
            echo "✓ Longhorn storage is available"
        else
            echo "✗ Longhorn storage is not available"
        fi

        echo -e "\n=== Resource Usage ==="
        top -bn1 | head -10

    ' | tee -a "$LOG_FILE"
}

# Main monitoring loop
main() {
    echo "Starting Harvester installation monitoring..."
    echo "Target server: $SERVER_IP"
    echo "SSH key: $SSH_KEY"
    echo "Started at: $(date)"

    # Initial connectivity check
    if ! check_connectivity; then
        echo "Server is not reachable. Check if installation has started."
        exit 1
    fi

    # Wait for SSH to become available
    echo "Waiting for server to complete installation and SSH to become available..."
    if monitor_ssh; then
        echo "✓ Server is accessible via SSH"
    else
        echo "✗ Could not connect via SSH within timeout period"
        exit 1
    fi

    # Monitor installation progress
    echo "Monitoring installation progress..."
    monitor_installation

    # Check final cluster health
    echo "Performing final health check..."
    check_cluster_health

    echo "Monitoring completed at: $(date)"
    echo "Full log available in: $LOG_FILE"

    # Display access information
    echo -e "\n=== Access Information ==="
    echo "Harvester UI: https://$SERVER_IP:443"
    echo "SSH Access: ssh -i $SSH_KEY rancher@$SERVER_IP"
    echo "kubectl: ssh to server and use 'kubectl' command"
}

# Run main function
main "$@"