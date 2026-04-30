#!/bin/bash
# =============================================================================
# 03_collect_k8s.sh - Kubernetes Data Collection
# =============================================================================
# Part of the Lerian Infrastructure Scoring Tool v2.
#
# This file contains ALL Kubernetes data collection functions. Each function
# collects raw data from the cluster and stores it in global variables
# defined in 00_constants.sh.
#
# Dependencies:
#   - 00_constants.sh (global variables)
#   - 01_utils.sh     (log_info, log_success, trim)
#   - 02_k8s_helpers.sh (kubectl_ns_json, kubectl_ns_top_pods, kubectl_ns_events)
#
# Compatibility: Bash 3.2+ (no associative arrays, no namerefs)
# =============================================================================

# -----------------------------------------------------------------------------
# Individual Collection Functions
# -----------------------------------------------------------------------------

collect_cluster_info() {
    log_info "Collecting cluster information..."
    CLUSTER_NAME=$(kubectl config current-context 2>/dev/null || echo "Unknown")
    CLUSTER_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || echo "Unknown")
    K8S_VERSION=$(kubectl version -o json 2>/dev/null | jq -r '.serverVersion.gitVersion' 2>/dev/null || true)
    if [ -z "$K8S_VERSION" ]; then
        K8S_VERSION=$(kubectl version --short 2>/dev/null | grep "Server" | awk '{print $3}' || true)
    fi
    K8S_VERSION="${K8S_VERSION:-Unknown}"
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "0")
}

collect_node_metrics() {
    log_info "Collecting node metrics..."
    NODE_INFO=$(kubectl get nodes -o json 2>/dev/null || echo '{"items":[]}')
    if [ "$METRICS_AVAILABLE" = true ]; then
        NODE_USAGE=$(kubectl top nodes --no-headers 2>/dev/null || echo "")
    else
        NODE_USAGE=""
    fi
}

collect_pod_metrics() {
    log_info "Collecting pod metrics from namespaces: ${TARGET_NAMESPACES}..."
    POD_INFO=$(kubectl_ns_json pods)
    if [ "$METRICS_AVAILABLE" = true ]; then
        POD_USAGE=$(kubectl_ns_top_pods)
    else
        POD_USAGE=""
    fi
}

collect_deployment_metrics() {
    log_info "Collecting deployment metrics..."
    DEPLOYMENT_INFO=$(kubectl_ns_json deployments)
}

collect_statefulset_metrics() {
    log_info "Collecting statefulset metrics..."
    STATEFULSET_INFO=$(kubectl_ns_json statefulsets)
}

collect_daemonset_metrics() {
    log_info "Collecting daemonset metrics..."
    DAEMONSET_INFO=$(kubectl_ns_json daemonsets)
}

collect_replicaset_metrics() {
    log_info "Collecting replicaset metrics..."
    REPLICASET_INFO=$(kubectl_ns_json replicasets)
}

collect_service_metrics() {
    log_info "Collecting service metrics..."
    SERVICE_INFO=$(kubectl_ns_json services)
}

collect_ingress_metrics() {
    log_info "Collecting ingress metrics..."
    INGRESS_INFO=$(kubectl_ns_json ingress)
}

collect_networkpolicy_metrics() {
    log_info "Collecting network policy metrics..."
    NETWORKPOLICY_INFO=$(kubectl_ns_json networkpolicies)
}

collect_configmap_metrics() {
    log_info "Collecting configmap metrics..."
    CONFIGMAP_INFO=$(kubectl_ns_json configmaps)
}

collect_secret_metrics() {
    log_info "Collecting secret metadata..."
    SECRET_INFO=$(kubectl_ns_json secrets)
}

collect_storageclass_metrics() {
    log_info "Collecting storage classes..."
    STORAGECLASS_INFO=$(kubectl get storageclass -o json 2>/dev/null || echo '{"items":[]}')
}

collect_storage_metrics() {
    log_info "Collecting persistent volumes and claims..."
    PV_INFO=$(kubectl get pv -o json 2>/dev/null || echo '{"items":[]}')
    PVC_INFO=$(kubectl_ns_json pvc)
}

collect_event_metrics() {
    log_info "Collecting events..."
    EVENT_INFO=$(kubectl_ns_events)
}

collect_quota_metrics() {
    log_info "Collecting resource quotas..."
    QUOTA_INFO=$(kubectl_ns_json resourcequota)
}

collect_endpoint_metrics() {
    log_info "Collecting network endpoints..."
    ENDPOINT_INFO=$(kubectl_ns_json endpoints)
}

collect_rbac_metrics() {
    log_info "Collecting RBAC configuration..."
    local cluster_roles
    local cluster_bindings
    local roles
    local bindings
    local service_accounts
    cluster_roles=$(kubectl get clusterroles -o json 2>/dev/null || echo '{"items":[]}')
    cluster_bindings=$(kubectl get clusterrolebindings -o json 2>/dev/null || echo '{"items":[]}')
    roles=$(kubectl_ns_json roles)
    bindings=$(kubectl_ns_json rolebindings)
    service_accounts=$(kubectl_ns_json serviceaccounts)
    if command -v jq &>/dev/null; then
        RBAC_INFO=$(jq -n \
            --argjson cr "$cluster_roles" \
            --argjson crb "$cluster_bindings" \
            --argjson r "$roles" \
            --argjson rb "$bindings" \
            --argjson sa "$service_accounts" \
            '{clusterRoles: $cr, clusterRoleBindings: $crb, roles: $r, roleBindings: $rb, serviceAccounts: $sa}' 2>/dev/null || echo '{}')
    else
        RBAC_INFO='{"note":"jq not available"}'
    fi
}

# -----------------------------------------------------------------------------
# Master Collection Function
# -----------------------------------------------------------------------------

collect_all_k8s() {
    collect_cluster_info
    collect_node_metrics
    collect_pod_metrics
    collect_deployment_metrics
    collect_statefulset_metrics
    collect_daemonset_metrics
    collect_replicaset_metrics
    collect_service_metrics
    collect_ingress_metrics
    collect_networkpolicy_metrics
    collect_configmap_metrics
    collect_secret_metrics
    collect_storageclass_metrics
    collect_storage_metrics
    collect_event_metrics
    collect_quota_metrics
    collect_endpoint_metrics
    collect_rbac_metrics
    log_success "K8s data collection complete"
}
