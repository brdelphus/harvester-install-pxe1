#!/bin/bash

# Harvester Cluster Health Check Script
# Comprehensive health verification for Harvester deployment

HARVESTER_IP="${1:-}"
SSH_KEY="${2:-~/.ssh/id_rsa}"

if [ -z "$HARVESTER_IP" ]; then
    echo "Usage: $0 <harvester_ip> [ssh_key_path]"
    echo "Example: $0 192.168.1.100 ~/.ssh/id_rsa"
    exit 1
fi

echo "=== Harvester Cluster Health Check ==="
echo "Target: $HARVESTER_IP"
echo "Timestamp: $(date)"
echo "============================================"

# Health check functions
check_ui_access() {
    echo "1. Checking Harvester UI accessibility..."
    if curl -k -s --connect-timeout 10 "https://$HARVESTER_IP:443" >/dev/null; then
        echo "   ✓ Harvester UI is accessible at https://$HARVESTER_IP:443"
        return 0
    else
        echo "   ✗ Harvester UI is not accessible"
        return 1
    fi
}

check_ssh_access() {
    echo "2. Checking SSH access..."
    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -i "$SSH_KEY" rancher@"$HARVESTER_IP" "echo 'SSH OK'" >/dev/null 2>&1; then
        echo "   ✓ SSH access is working"
        return 0
    else
        echo "   ✗ SSH access failed"
        return 1
    fi
}

check_system_resources() {
    echo "3. Checking system resources..."
    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" rancher@"$HARVESTER_IP" '
        echo "   CPU and Memory:"
        echo "   $(nproc) CPU cores, $(free -h | grep Mem: | awk "{print \$2}") total memory"

        # Check memory usage
        mem_usage=$(free | grep Mem | awk "{printf \"%.1f\", \$3/\$2 * 100.0}")
        if (( $(echo "$mem_usage > 80" | bc -l) )); then
            echo "   ⚠  High memory usage: ${mem_usage}%"
        else
            echo "   ✓ Memory usage OK: ${mem_usage}%"
        fi

        # Check disk usage
        echo "   Disk usage:"
        df -h | grep -E "(/$|/var|/opt)" | while read line; do
            usage=$(echo $line | awk "{print \$5}" | sed "s/%//")
            mount=$(echo $line | awk "{print \$6}")
            if [ "$usage" -gt 80 ]; then
                echo "   ⚠  High disk usage on $mount: ${usage}%"
            else
                echo "   ✓ Disk usage OK on $mount: ${usage}%"
            fi
        done
    '
}

check_kubernetes_status() {
    echo "4. Checking Kubernetes cluster status..."
    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" rancher@"$HARVESTER_IP" '
        if command -v kubectl >/dev/null 2>&1; then
            echo "   Kubernetes API:"
            if kubectl get nodes >/dev/null 2>&1; then
                echo "   ✓ Kubernetes API is responsive"

                # Check node status
                ready_nodes=$(kubectl get nodes --no-headers | grep " Ready " | wc -l)
                total_nodes=$(kubectl get nodes --no-headers | wc -l)
                echo "   ✓ Nodes: $ready_nodes/$total_nodes ready"

                if [ "$ready_nodes" -eq "$total_nodes" ] && [ "$total_nodes" -gt 0 ]; then
                    echo "   ✓ All nodes are ready"
                else
                    echo "   ⚠  Some nodes are not ready"
                    kubectl get nodes
                fi
            else
                echo "   ✗ Kubernetes API is not responsive"
            fi
        else
            echo "   ✗ kubectl is not available"
        fi
    '
}

check_harvester_services() {
    echo "5. Checking Harvester services..."
    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" rancher@"$HARVESTER_IP" '
        echo "   Core services status:"
        services=("harvester" "rancher-system-agent" "k3s" "rke2-server")

        for service in "${services[@]}"; do
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                echo "   ✓ $service is running"
            elif systemctl list-units --full -all | grep -q "$service"; then
                echo "   ⚠  $service is installed but not running"
            else
                echo "   - $service is not installed"
            fi
        done
    '
}

check_storage_system() {
    echo "6. Checking storage system (Longhorn)..."
    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" rancher@"$HARVESTER_IP" '
        if kubectl get namespace longhorn-system >/dev/null 2>&1; then
            echo "   ✓ Longhorn namespace exists"

            # Check Longhorn pods
            longhorn_pods=$(kubectl get pods -n longhorn-system --no-headers 2>/dev/null | wc -l)
            running_pods=$(kubectl get pods -n longhorn-system --no-headers 2>/dev/null | grep Running | wc -l)

            if [ "$longhorn_pods" -gt 0 ]; then
                echo "   ✓ Longhorn pods: $running_pods/$longhorn_pods running"
                if [ "$running_pods" -eq "$longhorn_pods" ]; then
                    echo "   ✓ All Longhorn pods are running"
                else
                    echo "   ⚠  Some Longhorn pods are not running"
                fi
            else
                echo "   ⚠  No Longhorn pods found"
            fi
        else
            echo "   ✗ Longhorn namespace not found"
        fi
    '
}

check_network_connectivity() {
    echo "7. Checking network connectivity..."
    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" rancher@"$HARVESTER_IP" '
        echo "   Network interfaces:"
        ip link show | grep "state UP" | awk -F: "{print \"   ✓ \" \$2}" | sed "s/ *//g"

        echo "   External connectivity:"
        if ping -c 2 8.8.8.8 >/dev/null 2>&1; then
            echo "   ✓ Internet connectivity OK"
        else
            echo "   ⚠  Internet connectivity issues"
        fi
    '
}

check_harvester_pods() {
    echo "8. Checking Harvester-specific pods..."
    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" rancher@"$HARVESTER_IP" '
        namespaces=("harvester-system" "cattle-system" "fleet-system")

        for ns in "${namespaces[@]}"; do
            if kubectl get namespace "$ns" >/dev/null 2>&1; then
                pod_count=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l)
                running_count=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep Running | wc -l)
                echo "   ✓ $ns: $running_count/$pod_count pods running"
            else
                echo "   - $ns: namespace not found"
            fi
        done
    '
}

generate_summary() {
    echo ""
    echo "=== Health Check Summary ==="
    echo "Harvester deployment appears to be:"

    if [ "$ui_ok" = "1" ] && [ "$ssh_ok" = "1" ]; then
        echo "✓ HEALTHY - Core services are accessible"
        echo ""
        echo "Next steps:"
        echo "1. Access Harvester UI: https://$HARVESTER_IP:443"
        echo "2. SSH access: ssh -i $SSH_KEY rancher@$HARVESTER_IP"
        echo "3. Run: ./harvester-monitoring.sh $HARVESTER_IP $SSH_KEY"
        echo "4. Configure additional storage and networking as needed"
    else
        echo "⚠  NEEDS ATTENTION - Some services may not be ready"
        echo ""
        echo "Troubleshooting:"
        echo "1. Wait 10-15 minutes for services to fully start"
        echo "2. Check server logs: ssh -i $SSH_KEY rancher@$HARVESTER_IP"
        echo "3. Review installation logs: sudo journalctl -u harvester"
    fi
}

# Run all health checks
ui_ok=0
ssh_ok=0

check_ui_access && ui_ok=1
check_ssh_access && ssh_ok=1

if [ "$ssh_ok" = "1" ]; then
    check_system_resources
    check_kubernetes_status
    check_harvester_services
    check_storage_system
    check_network_connectivity
    check_harvester_pods
fi

generate_summary

echo ""
echo "Health check completed at: $(date)"