#!/bin/bash

# Harvester Post-Installation Configuration Script
# Run this script after successful Harvester deployment

HARVESTER_IP="${1:-}"
SSH_KEY="${2:-~/.ssh/id_rsa}"

if [ -z "$HARVESTER_IP" ]; then
    echo "Usage: $0 <harvester_ip> [ssh_key_path]"
    echo "Example: $0 192.168.1.100 ~/.ssh/id_rsa"
    exit 1
fi

echo "=== Harvester Post-Installation Configuration ==="
echo "Target: $HARVESTER_IP"
echo "Started: $(date)"
echo "================================================="

# Function to run remote commands
run_remote() {
    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" rancher@"$HARVESTER_IP" "$1"
}

# Configure additional storage pools
configure_storage() {
    echo "1. Configuring additional storage pools..."
    run_remote '
        echo "Current storage configuration:"
        kubectl get nodes -o json | jq -r ".items[].metadata.annotations" | grep -E "(storage|disk)" || echo "No storage annotations found"

        # Check available disks
        echo "Available disks:"
        lsblk | grep disk

        # Label nodes for storage if additional disks available
        if lsblk | grep -q "sd[b-z]"; then
            echo "Additional storage disks detected"

            # Apply storage labels to nodes
            for node in $(kubectl get nodes -o name | sed "s/node\///"); do
                kubectl label node "$node" node.longhorn.io/create-default-disk=true --overwrite
                echo "Labeled node $node for Longhorn storage"
            done
        else
            echo "No additional storage disks found"
        fi
    '
}

# Configure networking
configure_networking() {
    echo "2. Configuring advanced networking..."
    run_remote '
        # Create management network configuration
        cat > /tmp/mgmt-network.yaml << EOF
apiVersion: network.harvesterhci.io/v1beta1
kind: ClusterNetwork
metadata:
  name: mgmt
spec:
  description: Management network for Harvester cluster
EOF

        # Apply network configuration
        kubectl apply -f /tmp/mgmt-network.yaml || echo "Network configuration already exists"

        # Check network status
        echo "Network interfaces:"
        ip addr show | grep -E "inet.*scope global"

        # Configure VLAN networks if needed
        echo "Setting up VLAN networks..."
        cat > /tmp/vlan-config.yaml << EOF
apiVersion: network.harvesterhci.io/v1beta1
kind: VlanConfig
metadata:
  name: vlan-config
spec:
  clusterNetwork: mgmt
  uplink:
    linkAttributes:
      txQueueLen: 1000
  nodeSelector: {}
EOF

        kubectl apply -f /tmp/vlan-config.yaml || echo "VLAN configuration already exists"
    '
}

# Configure resource limits and quotas
configure_resources() {
    echo "3. Configuring resource limits and quotas..."
    run_remote '
        # Create default namespace with resource quotas
        cat > /tmp/default-quota.yaml << EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: default-quota
  namespace: default
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "10"
    count/secrets: "10"
    count/services: "5"
EOF

        kubectl apply -f /tmp/default-quota.yaml || echo "Resource quota already exists"

        # Create limit ranges
        cat > /tmp/default-limits.yaml << EOF
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: default
spec:
  limits:
  - default:
      cpu: "1"
      memory: "1Gi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    type: Container
EOF

        kubectl apply -f /tmp/default-limits.yaml || echo "Limit range already exists"
    '
}

# Setup monitoring and logging
setup_monitoring() {
    echo "4. Setting up monitoring and logging..."
    run_remote '
        # Enable harvester monitoring if not already enabled
        if ! kubectl get namespace cattle-monitoring-system >/dev/null 2>&1; then
            echo "Enabling Harvester monitoring..."
            # This would typically be done through the UI or Helm
            echo "Please enable monitoring through the Harvester UI"
        else
            echo "Monitoring namespace already exists"
        fi

        # Check for log collection
        echo "Checking log collection setup..."
        kubectl get pods -A | grep -E "(fluentd|fluent-bit|logrotate)" || echo "No log collection pods found"
    '
}

# Configure backup settings
configure_backup() {
    echo "5. Configuring backup settings..."
    run_remote '
        # Create backup storage class if S3 credentials available
        cat > /tmp/backup-config.yaml << EOF
# Example backup configuration - adjust for your S3/backup storage
apiVersion: v1
kind: Secret
metadata:
  name: s3-backup-secret
  namespace: longhorn-system
type: Opaque
data:
  AWS_ACCESS_KEY_ID: ""      # Base64 encoded
  AWS_SECRET_ACCESS_KEY: ""  # Base64 encoded
  AWS_ENDPOINTS: ""          # Base64 encoded S3 endpoint
---
apiVersion: longhorn.io/v1beta1
kind: BackupTarget
metadata:
  name: default
  namespace: longhorn-system
spec:
  backupTargetURL: s3://backup-bucket@region/
  credentialSecret: s3-backup-secret
EOF

        echo "Backup configuration template created at /tmp/backup-config.yaml"
        echo "Please configure with your actual S3 credentials and apply manually"
    '
}

# Setup security policies
configure_security() {
    echo "6. Configuring security policies..."
    run_remote '
        # Create network policies for namespace isolation
        cat > /tmp/default-netpol.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-harvester-system
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: harvester-system
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: harvester-system
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 443
EOF

        kubectl apply -f /tmp/default-netpol.yaml || echo "Network policies already exist"

        # Setup RBAC for additional users if needed
        echo "RBAC configuration:"
        kubectl get clusterroles | grep harvester || echo "No custom Harvester roles found"
    '
}

# Optimize performance settings
optimize_performance() {
    echo "7. Optimizing performance settings..."
    run_remote '
        # Optimize kernel parameters
        echo "Current kernel parameters:"
        sysctl vm.swappiness
        sysctl net.core.rmem_max
        sysctl net.core.wmem_max

        # Create performance tuning script
        cat > /tmp/performance-tuning.sh << "EOF"
#!/bin/bash
# Performance tuning for Harvester

# Disable swap for better Kubernetes performance
sudo swapoff -a
sudo sed -i "/ swap / s/^/#/" /etc/fstab

# Network optimizations
echo "net.core.rmem_max = 134217728" | sudo tee -a /etc/sysctl.conf
echo "net.core.wmem_max = 134217728" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_rmem = 4096 131072 134217728" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_wmem = 4096 65536 134217728" | sudo tee -a /etc/sysctl.conf

# Apply settings
sudo sysctl -p

echo "Performance tuning applied"
EOF

        chmod +x /tmp/performance-tuning.sh
        echo "Performance tuning script created at /tmp/performance-tuning.sh"
        echo "Run it manually if needed: ./tmp/performance-tuning.sh"
    '
}

# Generate final configuration summary
generate_summary() {
    echo ""
    echo "=== Post-Installation Summary ==="
    run_remote '
        echo "Cluster Status:"
        kubectl get nodes -o wide

        echo -e "\nNamespaces:"
        kubectl get namespaces

        echo -e "\nStorage Classes:"
        kubectl get storageclass

        echo -e "\nPersistent Volumes:"
        kubectl get pv

        echo -e "\nServices in harvester-system:"
        kubectl get svc -n harvester-system
    '

    echo ""
    echo "=== Access Information ==="
    echo "Harvester UI: https://$HARVESTER_IP:443"
    echo "SSH Access: ssh -i $SSH_KEY rancher@$HARVESTER_IP"
    echo "kubectl: Access via SSH to the server"
    echo ""
    echo "=== Next Steps ==="
    echo "1. Configure backup storage (edit /tmp/backup-config.yaml)"
    echo "2. Enable monitoring through Harvester UI"
    echo "3. Create VM templates and networks as needed"
    echo "4. Add additional nodes to the cluster if required"
    echo "5. Configure external load balancer if needed"
}

# Main execution
main() {
    echo "Starting post-installation configuration..."

    # Verify SSH access first
    if ! run_remote "echo 'SSH connection test successful'"; then
        echo "Error: Cannot connect to $HARVESTER_IP via SSH"
        echo "Please verify the server is accessible and SSH keys are configured"
        exit 1
    fi

    configure_storage
    configure_networking
    configure_resources
    setup_monitoring
    configure_backup
    configure_security
    optimize_performance
    generate_summary

    echo ""
    echo "Post-installation configuration completed at: $(date)"
}

# Run main function
main "$@"