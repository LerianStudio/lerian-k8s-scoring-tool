#!/bin/bash
# =============================================================================
# 21_report_k8s.sh - Kubernetes Report Body Generation (Markdown)
# =============================================================================
# Part of the Lerian Infrastructure Scoring Tool v2.
#
# Generates ALL K8s report body sections as markdown written to stdout.
# Each function is self-contained and prints one major section.
#
# Dependencies:
#   - 00_constants.sh (global variables, weights)
#   - 01_util.sh      (get_rating_text, get_rating_emoji, get_rating_bar,
#                       format_bytes, convert_to_bytes, json_val, trim)
#   - 03_collect_k8s.sh (data collection populates globals)
#   - 10_score_k8s.sh   (scoring populates K8S_SCORE_*, K8S_RATING_*, etc.)
#   - lang_get / lang_get_block (i18n — stubs OK until Milestone 7)
#
# Compatibility: Bash 3.2+ (no associative arrays, no namerefs, no declare -A)
# =============================================================================

# -----------------------------------------------------------------------------
# Fallback stubs for lang_get / lang_get_block if not yet loaded
# -----------------------------------------------------------------------------
if ! type lang_get &>/dev/null; then
    lang_get() { echo "$1"; }
fi
if ! type lang_get_block &>/dev/null; then
    lang_get_block() { :; }
fi

# =============================================================================
# 1. NODES — Node Infrastructure
# =============================================================================
report_nodes() {
    echo "## $(lang_get "node_infrastructure")"
    echo ""

    # ---- Node Summary Table ----
    echo "### $(lang_get "node_summary")"
    echo ""
    echo "> **Context:** Real-time node health and resource utilization from the Kubernetes cluster."
    echo ""
    echo "| $(lang_get "th_node_name") | $(lang_get "th_status") | $(lang_get "th_cpu_cores") | $(lang_get "th_cpu_pct") | $(lang_get "th_mem_bytes") | $(lang_get "th_mem_pct") |"
    echo "|---|---|---|---|---|---|"

    local total_nodes=0
    local ready_count=0
    total_nodes=$(echo "$NODE_INFO" | jq '.items | length' 2>/dev/null || echo "0")

    local i=0
    while [ "$i" -lt "$total_nodes" ]; do
        local name status cpu_cores cpu_pct mem_bytes mem_pct

        name=$(echo "$NODE_INFO" | jq -r ".items[$i].metadata.name" 2>/dev/null || echo "unknown")

        # Determine Ready status
        local ready_val
        ready_val=$(echo "$NODE_INFO" | jq -r ".items[$i].status.conditions[] | select(.type==\"Ready\") | .status" 2>/dev/null || echo "Unknown")
        if [ "$ready_val" = "True" ]; then
            status="Ready"
            ready_count=$((ready_count + 1))
        else
            status="NotReady"
        fi

        # Match usage from NODE_USAGE text
        cpu_cores="-"
        cpu_pct="-"
        mem_bytes="-"
        mem_pct="-"
        if [ -n "$NODE_USAGE" ]; then
            local usage_line
            usage_line=$(echo "$NODE_USAGE" | while read -r line; do
                local uname
                uname=$(echo "$line" | awk '{print $1}')
                if [ "$uname" = "$name" ]; then
                    echo "$line"
                    break
                fi
            done)
            if [ -n "$usage_line" ]; then
                cpu_cores=$(echo "$usage_line" | awk '{print $2}')
                cpu_pct=$(echo "$usage_line" | awk '{print $3}')
                mem_bytes=$(echo "$usage_line" | awk '{print $4}')
                mem_pct=$(echo "$usage_line" | awk '{print $5}')
            fi
        fi

        echo "| $name | $status | $cpu_cores | $cpu_pct | $mem_bytes | $mem_pct |"
        i=$((i + 1))
    done

    echo ""
    if [ "$ready_count" -eq "$total_nodes" ] && [ "$total_nodes" -gt 0 ]; then
        echo "All $total_nodes nodes in Ready state."
    else
        echo "$ready_count of $total_nodes nodes in Ready state."
    fi
    echo ""
    lang_get_block "wgll_nodes"

    # ---- Node Capacity Table ----
    echo ""
    echo "### $(lang_get "node_capacity")"
    echo ""
    echo "| $(lang_get "th_node_name") | $(lang_get "th_cpu_capacity") | $(lang_get "th_cpu_allocatable") | $(lang_get "th_mem_capacity") | $(lang_get "th_mem_allocatable") |"
    echo "|---|---|---|---|---|"

    i=0
    while [ "$i" -lt "$total_nodes" ]; do
        local name cpu_cap cpu_alloc mem_cap mem_alloc

        name=$(echo "$NODE_INFO" | jq -r ".items[$i].metadata.name" 2>/dev/null || echo "unknown")
        cpu_cap=$(echo "$NODE_INFO" | jq -r ".items[$i].status.capacity.cpu // \"-\"" 2>/dev/null || echo "-")
        cpu_alloc=$(echo "$NODE_INFO" | jq -r ".items[$i].status.allocatable.cpu // \"-\"" 2>/dev/null || echo "-")
        mem_cap=$(echo "$NODE_INFO" | jq -r ".items[$i].status.capacity.memory // \"-\"" 2>/dev/null || echo "-")
        mem_alloc=$(echo "$NODE_INFO" | jq -r ".items[$i].status.allocatable.memory // \"-\"" 2>/dev/null || echo "-")

        echo "| $name | $cpu_cap | $cpu_alloc | $mem_cap | $mem_alloc |"
        i=$((i + 1))
    done

    echo ""
    if [ "$total_nodes" -gt 0 ]; then
        local total_cpu_cap
        total_cpu_cap=$(echo "$NODE_INFO" | jq '[.items[].status.capacity.cpu | tonumber] | add' 2>/dev/null || echo "0")
        local total_cpu_alloc
        total_cpu_alloc=$(echo "$NODE_INFO" | jq '[.items[].status.allocatable.cpu | tonumber] | add' 2>/dev/null || echo "0")
        echo "**Total cluster CPU capacity:** ${total_cpu_cap:-0} cores, **allocatable:** ${total_cpu_alloc:-0} cores"
    fi
    echo ""
    lang_get_block "wgll_node_capacity"

    echo ""
    echo "---"
}

# =============================================================================
# 2. WORKLOADS — Pod / Deployment / Resource Requests & Limits
# =============================================================================
report_workloads() {
    echo "## $(lang_get "workload_metrics")"
    echo ""

    # ---- Pod Resource Usage ----
    echo "### $(lang_get "pod_usage")"
    echo ""

    if [ -z "$POD_USAGE" ]; then
        echo "> $(lang_get "metrics_server_note")"
        echo ""
    else
        echo "| $(lang_get "th_namespace") | $(lang_get "th_pod_name") | $(lang_get "th_cpu_cores") | $(lang_get "th_mem_bytes") |"
        echo "|---|---|---|---|"

        echo "$POD_USAGE" | while read -r line; do
            if [ -z "$line" ]; then continue; fi
            local ns pod_name cpu mem
            ns=$(echo "$line" | awk '{print $1}')
            pod_name=$(echo "$line" | awk '{print $2}')
            cpu=$(echo "$line" | awk '{print $3}')
            mem=$(echo "$line" | awk '{print $4}')
            echo "| $ns | $pod_name | $cpu | $mem |"
        done
        echo ""
    fi

    lang_get_block "wgll_pods"
    echo ""

    # ---- Deployment Status ----
    echo "### $(lang_get "deployment_status")"
    echo ""
    echo "| $(lang_get "th_namespace") | $(lang_get "th_deploy_name") | $(lang_get "th_replicas") | $(lang_get "th_ready") | $(lang_get "th_available") | $(lang_get "th_status") |"
    echo "|---|---|---|---|---|---|"

    local dep_count
    dep_count=$(echo "$DEPLOYMENT_INFO" | jq '.items | length' 2>/dev/null || echo "0")

    local d=0
    while [ "$d" -lt "$dep_count" ]; do
        local ns dep_name desired ready available status

        ns=$(echo "$DEPLOYMENT_INFO" | jq -r ".items[$d].metadata.namespace // \"-\"" 2>/dev/null || echo "-")
        dep_name=$(echo "$DEPLOYMENT_INFO" | jq -r ".items[$d].metadata.name // \"-\"" 2>/dev/null || echo "-")
        desired=$(echo "$DEPLOYMENT_INFO" | jq -r ".items[$d].spec.replicas // 0" 2>/dev/null || echo "0")
        ready=$(echo "$DEPLOYMENT_INFO" | jq -r ".items[$d].status.readyReplicas // 0" 2>/dev/null || echo "0")
        available=$(echo "$DEPLOYMENT_INFO" | jq -r ".items[$d].status.availableReplicas // 0" 2>/dev/null || echo "0")

        if [ "$ready" = "$desired" ] && [ "$desired" != "0" ]; then
            status="$(lang_get "status_healthy")"
        else
            status="$(lang_get "status_degraded")"
        fi

        echo "| $ns | $dep_name | $desired | $ready | $available | $status |"
        d=$((d + 1))
    done

    echo ""
    lang_get_block "wgll_deployments"
    echo ""

    # ---- Resource Requests & Limits ----
    echo "### $(lang_get "resource_requests")"
    echo ""
    echo "| $(lang_get "th_namespace") | $(lang_get "th_pod_name") | $(lang_get "th_container") | $(lang_get "th_cpu_request") | $(lang_get "th_cpu_limit") | $(lang_get "th_mem_request") | $(lang_get "th_mem_limit") |"
    echo "|---|---|---|---|---|---|---|"

    local pod_count
    pod_count=$(echo "$POD_INFO" | jq '.items | length' 2>/dev/null || echo "0")

    local p=0
    while [ "$p" -lt "$pod_count" ]; do
        local ns pod_name
        ns=$(echo "$POD_INFO" | jq -r ".items[$p].metadata.namespace // \"-\"" 2>/dev/null || echo "-")
        pod_name=$(echo "$POD_INFO" | jq -r ".items[$p].metadata.name // \"-\"" 2>/dev/null || echo "-")

        local container_count
        container_count=$(echo "$POD_INFO" | jq ".items[$p].spec.containers | length" 2>/dev/null || echo "0")

        local c=0
        while [ "$c" -lt "$container_count" ]; do
            local cname cpu_req cpu_lim mem_req mem_lim
            cname=$(echo "$POD_INFO" | jq -r ".items[$p].spec.containers[$c].name // \"-\"" 2>/dev/null || echo "-")
            cpu_req=$(echo "$POD_INFO" | jq -r ".items[$p].spec.containers[$c].resources.requests.cpu // \"not set\"" 2>/dev/null || echo "not set")
            cpu_lim=$(echo "$POD_INFO" | jq -r ".items[$p].spec.containers[$c].resources.limits.cpu // \"not set\"" 2>/dev/null || echo "not set")
            mem_req=$(echo "$POD_INFO" | jq -r ".items[$p].spec.containers[$c].resources.requests.memory // \"not set\"" 2>/dev/null || echo "not set")
            mem_lim=$(echo "$POD_INFO" | jq -r ".items[$p].spec.containers[$c].resources.limits.memory // \"not set\"" 2>/dev/null || echo "not set")

            echo "| $ns | $pod_name | $cname | $cpu_req | $cpu_lim | $mem_req | $mem_lim |"
            c=$((c + 1))
        done

        p=$((p + 1))
    done

    echo ""
    lang_get_block "wgll_resources"

    echo ""
    echo "---"
}

# =============================================================================
# 3. SECURITY — Security & RBAC
# =============================================================================
report_security() {
    echo "## $(lang_get "security_rbac")"
    echo ""

    # ---- RBAC Overview ----
    echo "### $(lang_get "rbac_overview")"
    echo ""

    local cr_count=0 crb_count=0 admin_count=0 wildcard_count=0

    if [ -n "$RBAC_INFO" ] && [ "$RBAC_INFO" != "{}" ]; then
        cr_count=$(echo "$RBAC_INFO" | jq '.clusterRoles.items // [] | length' 2>/dev/null || echo "0")
        crb_count=$(echo "$RBAC_INFO" | jq '.clusterRoleBindings.items // [] | length' 2>/dev/null || echo "0")
        admin_count=$(echo "$RBAC_INFO" | jq '[.clusterRoleBindings.items // [] | .[] | select(.roleRef.name == "cluster-admin")] | length' 2>/dev/null || echo "0")
        wildcard_count=$(echo "$RBAC_INFO" | jq '[.clusterRoles.items // [] | .[] | select(.rules[]? | (.verbs[]? == "*") or (.resources[]? == "*"))] | length' 2>/dev/null || echo "0")
    fi

    echo "- **ClusterRoles:** $cr_count"
    echo "- **ClusterRoleBindings:** $crb_count"
    echo "- **cluster-admin bindings:** $admin_count"
    echo "- **ClusterRoles with wildcard rules:** $wildcard_count"
    echo ""

    # ---- Pod Security Findings ----
    echo "### $(lang_get "pod_security_findings")"
    echo ""

    local privileged_count=0 hostnet_count=0 hostpid_count=0
    local nonroot_violations=0 readonly_count=0

    local pod_count
    pod_count=$(echo "$POD_INFO" | jq '.items | length' 2>/dev/null || echo "0")

    if [ "$pod_count" -gt 0 ] 2>/dev/null; then
        privileged_count=$(echo "$POD_INFO" | jq '[.items[].spec.containers[]? | select(.securityContext.privileged == true)] | length' 2>/dev/null || echo "0")
        hostnet_count=$(echo "$POD_INFO" | jq '[.items[] | select(.spec.hostNetwork == true)] | length' 2>/dev/null || echo "0")
        hostpid_count=$(echo "$POD_INFO" | jq '[.items[] | select(.spec.hostPID == true)] | length' 2>/dev/null || echo "0")
        nonroot_violations=$(echo "$POD_INFO" | jq '[.items[].spec.containers[]? | select((.securityContext.runAsNonRoot // false) != true)] | length' 2>/dev/null || echo "0")
        readonly_count=$(echo "$POD_INFO" | jq '[.items[].spec.containers[]? | select((.securityContext.readOnlyRootFilesystem // false) != true)] | length' 2>/dev/null || echo "0")
    fi

    echo "- **Privileged containers:** $privileged_count"
    echo "- **Pods with hostNetwork:** $hostnet_count"
    echo "- **Pods with hostPID:** $hostpid_count"
    echo "- **Containers without runAsNonRoot:** $nonroot_violations"
    echo "- **Containers without readOnlyRootFilesystem:** $readonly_count"
    echo ""

    # ---- Network Policy Coverage ----
    echo "### $(lang_get "network_policy_coverage")"
    echo ""

    local netpol_count
    netpol_count=$(echo "$NETWORKPOLICY_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    echo "- **Total NetworkPolicies:** $netpol_count"

    # Per-namespace breakdown
    if [ "$netpol_count" -gt 0 ] 2>/dev/null; then
        local ns_list
        ns_list=$(echo "$NETWORKPOLICY_INFO" | jq -r '[.items[].metadata.namespace] | unique | .[]' 2>/dev/null || echo "")
        if [ -n "$ns_list" ]; then
            echo "$ns_list" | while read -r ns; do
                if [ -z "$ns" ]; then continue; fi
                local cnt
                cnt=$(echo "$NETWORKPOLICY_INFO" | jq "[.items[] | select(.metadata.namespace == \"$ns\")] | length" 2>/dev/null || echo "0")
                echo "  - $ns: $cnt"
            done
        fi
    fi

    echo ""
    lang_get_block "wgll_security"

    echo ""
    echo "---"
}

# =============================================================================
# 4. STORAGE — Storage Resources
# =============================================================================
report_storage() {
    echo "## $(lang_get "storage_section")"
    echo ""

    # ---- StorageClass Table ----
    echo "### $(lang_get "storageclasses")"
    echo ""

    local sc_count
    sc_count=$(echo "$STORAGECLASS_INFO" | jq '.items | length' 2>/dev/null || echo "0")

    if [ "$sc_count" -gt 0 ] 2>/dev/null; then
        echo "| $(lang_get "th_name") | $(lang_get "th_provisioner") | $(lang_get "th_reclaim_policy") | $(lang_get "th_default") |"
        echo "|---|---|---|---|"

        local s=0
        while [ "$s" -lt "$sc_count" ]; do
            local sc_name provisioner reclaim is_default

            sc_name=$(echo "$STORAGECLASS_INFO" | jq -r ".items[$s].metadata.name // \"-\"" 2>/dev/null || echo "-")
            provisioner=$(echo "$STORAGECLASS_INFO" | jq -r ".items[$s].provisioner // \"-\"" 2>/dev/null || echo "-")
            reclaim=$(echo "$STORAGECLASS_INFO" | jq -r ".items[$s].reclaimPolicy // \"-\"" 2>/dev/null || echo "-")

            local default_anno
            default_anno=$(echo "$STORAGECLASS_INFO" | jq -r ".items[$s].metadata.annotations[\"storageclass.kubernetes.io/is-default-class\"] // \"false\"" 2>/dev/null || echo "false")
            if [ "$default_anno" = "true" ]; then
                is_default="Yes"
            else
                is_default="No"
            fi

            echo "| $sc_name | $provisioner | $reclaim | $is_default |"
            s=$((s + 1))
        done
    else
        echo "No StorageClasses found."
    fi

    echo ""

    # ---- PV Summary ----
    echo "### $(lang_get "persistent_volumes")"
    echo ""

    local pv_count pv_bound pv_available
    pv_count=$(echo "$PV_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    pv_bound=$(echo "$PV_INFO" | jq '[.items[] | select(.status.phase == "Bound")] | length' 2>/dev/null || echo "0")
    pv_available=$(echo "$PV_INFO" | jq '[.items[] | select(.status.phase == "Available")] | length' 2>/dev/null || echo "0")

    echo "- **Total PVs:** $pv_count"
    echo "- **Bound:** $pv_bound"
    echo "- **Available:** $pv_available"
    echo ""

    # ---- PVC Table ----
    echo "### $(lang_get "pvc_section")"
    echo ""

    local pvc_count
    pvc_count=$(echo "$PVC_INFO" | jq '.items | length' 2>/dev/null || echo "0")

    if [ "$pvc_count" -gt 0 ] 2>/dev/null; then
        echo "| $(lang_get "th_namespace") | $(lang_get "th_name") | $(lang_get "th_status") | $(lang_get "th_capacity") | $(lang_get "th_storage_class") |"
        echo "|---|---|---|---|---|"

        local v=0
        while [ "$v" -lt "$pvc_count" ]; do
            local ns pvc_name pvc_status pvc_cap pvc_sc

            ns=$(echo "$PVC_INFO" | jq -r ".items[$v].metadata.namespace // \"-\"" 2>/dev/null || echo "-")
            pvc_name=$(echo "$PVC_INFO" | jq -r ".items[$v].metadata.name // \"-\"" 2>/dev/null || echo "-")
            pvc_status=$(echo "$PVC_INFO" | jq -r ".items[$v].status.phase // \"-\"" 2>/dev/null || echo "-")
            pvc_cap=$(echo "$PVC_INFO" | jq -r ".items[$v].status.capacity.storage // \"-\"" 2>/dev/null || echo "-")
            pvc_sc=$(echo "$PVC_INFO" | jq -r ".items[$v].spec.storageClassName // \"-\"" 2>/dev/null || echo "-")

            echo "| $ns | $pvc_name | $pvc_status | $pvc_cap | $pvc_sc |"
            v=$((v + 1))
        done
    else
        echo "No PVCs found."
    fi

    echo ""
    lang_get_block "wgll_storage"

    echo ""
    echo "---"
}

# =============================================================================
# 5. EVENTS — Events & Monitoring
# =============================================================================
report_events() {
    echo "## $(lang_get "events_section")"
    echo ""

    # ---- Event Summary ----
    echo "### $(lang_get "event_summary")"
    echo ""

    local total_events normal_count warning_count warning_pct
    total_events=$(echo "$EVENT_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    normal_count=$(echo "$EVENT_INFO" | jq '[.items[] | select(.type == "Normal")] | length' 2>/dev/null || echo "0")
    warning_count=$(echo "$EVENT_INFO" | jq '[.items[] | select(.type == "Warning")] | length' 2>/dev/null || echo "0")

    if [ "$total_events" -gt 0 ] 2>/dev/null; then
        warning_pct=$(echo "scale=1; $warning_count * 100 / $total_events" | bc 2>/dev/null || echo "0")
    else
        warning_pct="0"
    fi

    echo "- **Total events:** $total_events"
    echo "- **Normal events:** $normal_count"
    echo "- **Warning events:** $warning_count"
    echo "- **Warning percentage:** ${warning_pct}%"
    echo ""

    # ---- Warning Events Table (last 20) ----
    if [ "$warning_count" -gt 0 ] 2>/dev/null; then
        echo "### $(lang_get "recent_warnings")"
        echo ""
        echo "| $(lang_get "th_namespace") | $(lang_get "th_reason") | $(lang_get "th_message") | $(lang_get "th_count") | $(lang_get "th_last_seen") |"
        echo "|---|---|---|---|---|"

        # Extract last 20 warning events
        local warnings_json
        warnings_json=$(echo "$EVENT_INFO" | jq '[.items[] | select(.type == "Warning")] | sort_by(.lastTimestamp) | reverse | .[0:20]' 2>/dev/null || echo "[]")

        local w_count
        w_count=$(echo "$warnings_json" | jq 'length' 2>/dev/null || echo "0")

        local w=0
        while [ "$w" -lt "$w_count" ]; do
            local ns reason message evt_count last_seen

            ns=$(echo "$warnings_json" | jq -r ".[$w].metadata.namespace // \"-\"" 2>/dev/null || echo "-")
            reason=$(echo "$warnings_json" | jq -r ".[$w].reason // \"-\"" 2>/dev/null || echo "-")
            message=$(echo "$warnings_json" | jq -r ".[$w].message // \"-\"" 2>/dev/null || echo "-")
            # Truncate long messages for table readability
            if [ ${#message} -gt 80 ]; then
                message="${message:0:77}..."
            fi
            evt_count=$(echo "$warnings_json" | jq -r ".[$w].count // 1" 2>/dev/null || echo "1")
            last_seen=$(echo "$warnings_json" | jq -r ".[$w].lastTimestamp // \"-\"" 2>/dev/null || echo "-")

            echo "| $ns | $reason | $message | $evt_count | $last_seen |"
            w=$((w + 1))
        done
        echo ""
    fi

    # ---- Metrics Server Status ----
    echo "### $(lang_get "metrics_server_status")"
    echo ""
    if [ "$METRICS_AVAILABLE" = "true" ] || [ "$METRICS_AVAILABLE" = true ]; then
        echo "$(lang_get "metrics_available")"
    else
        echo "$(lang_get "metrics_unavailable")"
    fi

    echo ""
    lang_get_block "wgll_events"

    echo ""
    echo "---"
}

# =============================================================================
# 6. NETWORKING — Services, Ingress, Network Policies
# =============================================================================
report_networking() {
    echo "## $(lang_get "networking_section")"
    echo ""

    # ---- Services Table ----
    echo "### $(lang_get "services")"
    echo ""

    local svc_count
    svc_count=$(echo "$SERVICE_INFO" | jq '.items | length' 2>/dev/null || echo "0")

    if [ "$svc_count" -gt 0 ] 2>/dev/null; then
        echo "| $(lang_get "th_namespace") | $(lang_get "th_name") | $(lang_get "th_type") | $(lang_get "th_cluster_ip") | $(lang_get "th_ports") |"
        echo "|---|---|---|---|---|"

        local s=0
        while [ "$s" -lt "$svc_count" ]; do
            local ns svc_name svc_type cluster_ip ports

            ns=$(echo "$SERVICE_INFO" | jq -r ".items[$s].metadata.namespace // \"-\"" 2>/dev/null || echo "-")
            svc_name=$(echo "$SERVICE_INFO" | jq -r ".items[$s].metadata.name // \"-\"" 2>/dev/null || echo "-")
            svc_type=$(echo "$SERVICE_INFO" | jq -r ".items[$s].spec.type // \"-\"" 2>/dev/null || echo "-")
            cluster_ip=$(echo "$SERVICE_INFO" | jq -r ".items[$s].spec.clusterIP // \"-\"" 2>/dev/null || echo "-")
            ports=$(echo "$SERVICE_INFO" | jq -r "[.items[$s].spec.ports[]? | \"\(.port)/\(.protocol // \"TCP\")\"] | join(\", \")" 2>/dev/null || echo "-")
            if [ -z "$ports" ]; then ports="-"; fi

            echo "| $ns | $svc_name | $svc_type | $cluster_ip | $ports |"
            s=$((s + 1))
        done
    else
        echo "No services found."
    fi

    echo ""

    # ---- Ingress Table ----
    echo "### $(lang_get "ingress_resources")"
    echo ""

    local ing_count
    ing_count=$(echo "$INGRESS_INFO" | jq '.items | length' 2>/dev/null || echo "0")

    if [ "$ing_count" -gt 0 ] 2>/dev/null; then
        echo "| $(lang_get "th_namespace") | $(lang_get "th_name") | $(lang_get "th_hosts") | $(lang_get "th_tls") |"
        echo "|---|---|---|---|"

        local g=0
        while [ "$g" -lt "$ing_count" ]; do
            local ns ing_name hosts tls

            ns=$(echo "$INGRESS_INFO" | jq -r ".items[$g].metadata.namespace // \"-\"" 2>/dev/null || echo "-")
            ing_name=$(echo "$INGRESS_INFO" | jq -r ".items[$g].metadata.name // \"-\"" 2>/dev/null || echo "-")
            hosts=$(echo "$INGRESS_INFO" | jq -r "[.items[$g].spec.rules[]?.host // \"-\"] | join(\", \")" 2>/dev/null || echo "-")
            if [ -z "$hosts" ]; then hosts="-"; fi

            local tls_count
            tls_count=$(echo "$INGRESS_INFO" | jq ".items[$g].spec.tls // [] | length" 2>/dev/null || echo "0")
            if [ "$tls_count" -gt 0 ] 2>/dev/null; then
                tls="Yes"
            else
                tls="No"
            fi

            echo "| $ns | $ing_name | $hosts | $tls |"
            g=$((g + 1))
        done
    else
        echo "No ingress resources found."
    fi

    echo ""

    # ---- Network Policy Count ----
    echo "### $(lang_get "network_policies")"
    echo ""
    local netpol_count
    netpol_count=$(echo "$NETWORKPOLICY_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    echo "- **Total NetworkPolicies:** $netpol_count"
    echo ""

    lang_get_block "wgll_networking"

    echo ""
    echo "---"
}

# =============================================================================
# 7. CONFIGURATION — Best Practices
# =============================================================================
report_config() {
    echo "## $(lang_get "config_section")"
    echo ""

    # ---- ResourceQuota Presence ----
    echo "### $(lang_get "resourcequota_coverage")"
    echo ""

    local quota_count
    quota_count=$(echo "$RESOURCEQUOTA_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    # Also check QUOTA_INFO if RESOURCEQUOTA_INFO is empty
    if [ "$quota_count" -eq 0 ] 2>/dev/null && [ -n "${QUOTA_INFO:-}" ]; then
        quota_count=$(echo "$QUOTA_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    fi

    if [ "$quota_count" -gt 0 ] 2>/dev/null; then
        echo "ResourceQuotas found: $quota_count"
        # List namespaces with quotas
        local quota_source="${RESOURCEQUOTA_INFO}"
        if [ "$(echo "$quota_source" | jq '.items | length' 2>/dev/null || echo "0")" -eq 0 ] && [ -n "${QUOTA_INFO:-}" ]; then
            quota_source="$QUOTA_INFO"
        fi
        local ns_list
        ns_list=$(echo "$quota_source" | jq -r '[.items[].metadata.namespace] | unique | .[]' 2>/dev/null || echo "")
        if [ -n "$ns_list" ]; then
            echo "$ns_list" | while read -r ns; do
                if [ -z "$ns" ]; then continue; fi
                echo "  - $ns"
            done
        fi
    else
        echo "$(lang_get "no_resourcequotas")"
    fi
    echo ""

    # ---- LimitRange Presence ----
    echo "### $(lang_get "limitrange_coverage")"
    echo ""

    local lr_count
    lr_count=$(echo "$LIMITRANGE_INFO" | jq '.items | length' 2>/dev/null || echo "0")

    if [ "$lr_count" -gt 0 ] 2>/dev/null; then
        echo "LimitRanges found: $lr_count"
        local ns_list
        ns_list=$(echo "$LIMITRANGE_INFO" | jq -r '[.items[].metadata.namespace] | unique | .[]' 2>/dev/null || echo "")
        if [ -n "$ns_list" ]; then
            echo "$ns_list" | while read -r ns; do
                if [ -z "$ns" ]; then continue; fi
                echo "  - $ns"
            done
        fi
    else
        echo "$(lang_get "no_limitranges")"
    fi
    echo ""

    # ---- PDB Presence ----
    echo "### $(lang_get "pdb_coverage")"
    echo ""

    local pdb_count
    pdb_count=$(echo "$PDB_INFO" | jq '.items | length' 2>/dev/null || echo "0")

    local dep_count
    dep_count=$(echo "$DEPLOYMENT_INFO" | jq '.items | length' 2>/dev/null || echo "0")

    echo "- **PDBs defined:** $pdb_count"
    echo "- **Deployments:** $dep_count"

    if [ "$dep_count" -gt 0 ] 2>/dev/null && [ "$pdb_count" -eq 0 ] 2>/dev/null; then
        echo ""
        echo "> No PodDisruptionBudgets found. Consider adding PDBs to protect availability during voluntary disruptions."
    fi
    echo ""

    # ---- Image Tag Analysis ----
    echo "### $(lang_get "image_tag_analysis")"
    echo ""

    local pod_count
    pod_count=$(echo "$POD_INFO" | jq '.items | length' 2>/dev/null || echo "0")

    local total_containers=0
    local latest_count=0
    local no_tag_count=0

    if [ "$pod_count" -gt 0 ] 2>/dev/null; then
        total_containers=$(echo "$POD_INFO" | jq '[.items[].spec.containers[]] | length' 2>/dev/null || echo "0")
        latest_count=$(echo "$POD_INFO" | jq '[.items[].spec.containers[].image | select(endswith(":latest"))] | length' 2>/dev/null || echo "0")
        no_tag_count=$(echo "$POD_INFO" | jq '[.items[].spec.containers[].image | select(contains(":") | not)] | length' 2>/dev/null || echo "0")
    fi

    echo "- **Total containers:** $total_containers"
    echo "- **Using :latest tag:** $latest_count"
    echo "- **Without explicit tag:** $no_tag_count"

    if [ "$latest_count" -gt 0 ] 2>/dev/null || [ "$no_tag_count" -gt 0 ] 2>/dev/null; then
        echo ""
        echo "> Using :latest or untagged images is discouraged. Pin images to specific versions for reproducibility and rollback safety."
    fi

    echo ""
    lang_get_block "wgll_config"

    echo ""
    echo "---"
}

# =============================================================================
# 8. SCORE ANALYSIS — Category Breakdown & Priority Improvements
# =============================================================================
report_score_analysis() {
    echo "## $(lang_get "score_analysis")"
    echo ""

    # Category list — parallel arrays for Bash 3.2 compatibility
    local cat_names="Nodes Workloads Resources Security Storage Events Networking Config"
    local cat_scores="$K8S_SCORE_NODES $K8S_SCORE_WORKLOADS $K8S_SCORE_RESOURCES $K8S_SCORE_SECURITY $K8S_SCORE_STORAGE $K8S_SCORE_EVENTS $K8S_SCORE_NETWORKING $K8S_SCORE_CONFIG"
    local cat_weights="$K8S_WEIGHT_NODES $K8S_WEIGHT_WORKLOADS $K8S_WEIGHT_RESOURCES $K8S_WEIGHT_SECURITY $K8S_WEIGHT_STORAGE $K8S_WEIGHT_EVENTS $K8S_WEIGHT_NETWORKING $K8S_WEIGHT_CONFIG"

    # Convert to indexed arrays (Bash 3.2 safe)
    set -- $cat_names
    local idx=1
    local name_1="$1" name_2="$2" name_3="$3" name_4="$4" name_5="$5" name_6="$6" name_7="$7" name_8="$8"

    set -- $cat_scores
    local score_1="$1" score_2="$2" score_3="$3" score_4="$4" score_5="$5" score_6="$6" score_7="$7" score_8="$8"

    set -- $cat_weights
    local weight_1="$1" weight_2="$2" weight_3="$3" weight_4="$4" weight_5="$5" weight_6="$6" weight_7="$7" weight_8="$8"

    echo "### $(lang_get "category_scores")"
    echo ""

    # Print each category score with bar and emoji
    local i=1
    while [ "$i" -le 8 ]; do
        local cname cscore cweight
        eval "cname=\$name_$i"
        eval "cscore=\$score_$i"
        eval "cweight=\$weight_$i"

        local bar emoji rating
        bar=$(get_rating_bar "$cscore")
        emoji=$(get_rating_emoji "$cscore")
        rating=$(get_rating_text "$cscore")

        echo "**$cname** (weight: ${cweight}%)"
        echo "$emoji $bar **${cscore}/100** — $rating"
        echo ""

        i=$((i + 1))
    done

    # ---- Overall ----
    echo "### $(lang_get "overall_k8s_score")"
    echo ""
    local overall_bar overall_emoji overall_rating
    overall_bar=$(get_rating_bar "$K8S_SCORE_OVERALL")
    overall_emoji=$(get_rating_emoji "$K8S_SCORE_OVERALL")
    overall_rating=$(get_rating_text "$K8S_SCORE_OVERALL")
    echo "$overall_emoji $overall_bar **${K8S_SCORE_OVERALL}/100** — $overall_rating"
    echo ""

    # ---- Findings per Category ----
    echo "### $(lang_get "key_findings")"
    echo ""

    # Nodes findings
    local total_nodes ready_nodes
    total_nodes=$(echo "$NODE_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    ready_nodes=$(echo "$NODE_INFO" | jq '[.items[] | select(.status.conditions[] | select(.type=="Ready" and .status=="True"))] | length' 2>/dev/null || echo "0")
    echo "- **$(lang_get "cat_nodes"):** $ready_nodes/$total_nodes nodes ready"

    # Workloads findings
    local dep_count healthy_deps
    dep_count=$(echo "$DEPLOYMENT_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    healthy_deps=$(echo "$DEPLOYMENT_INFO" | jq '[.items[] | select((.status.readyReplicas // 0) == (.spec.replicas // 0)) | select(.spec.replicas > 0)] | length' 2>/dev/null || echo "0")
    echo "- **$(lang_get "cat_workloads"):** $healthy_deps/$dep_count deployments healthy"

    # Resources findings
    local containers_with_limits total_containers
    total_containers=$(echo "$POD_INFO" | jq '[.items[].spec.containers[]] | length' 2>/dev/null || echo "0")
    containers_with_limits=$(echo "$POD_INFO" | jq '[.items[].spec.containers[] | select(.resources.limits.cpu != null and .resources.limits.memory != null)] | length' 2>/dev/null || echo "0")
    echo "- **$(lang_get "cat_resources"):** $containers_with_limits/$total_containers containers with CPU and memory limits"

    # Security findings
    local priv_count
    priv_count=$(echo "$POD_INFO" | jq '[.items[].spec.containers[]? | select(.securityContext.privileged == true)] | length' 2>/dev/null || echo "0")
    echo "- **$(lang_get "cat_security"):** $priv_count privileged containers found"

    # Storage findings
    local pvc_bound pvc_total
    pvc_total=$(echo "$PVC_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    pvc_bound=$(echo "$PVC_INFO" | jq '[.items[] | select(.status.phase == "Bound")] | length' 2>/dev/null || echo "0")
    echo "- **$(lang_get "cat_storage"):** $pvc_bound/$pvc_total PVCs bound"

    # Events findings
    local warning_events
    warning_events=$(echo "$EVENT_INFO" | jq '[.items[] | select(.type == "Warning")] | length' 2>/dev/null || echo "0")
    echo "- **$(lang_get "cat_events"):** $warning_events warning events"

    # Networking findings
    local netpol_count
    netpol_count=$(echo "$NETWORKPOLICY_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    echo "- **$(lang_get "cat_networking"):** $netpol_count network policies defined"

    # Config findings
    local quota_count pdb_count
    quota_count=$(echo "$RESOURCEQUOTA_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    if [ "$quota_count" -eq 0 ] 2>/dev/null && [ -n "${QUOTA_INFO:-}" ]; then
        quota_count=$(echo "$QUOTA_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    fi
    pdb_count=$(echo "$PDB_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    echo "- **$(lang_get "cat_config"):** $quota_count resource quotas, $pdb_count PDBs"

    echo ""

    # ---- Top Priority Improvements ----
    echo "### $(lang_get "top_priorities")"
    echo ""

    # Sort categories by score ascending, show those below 75
    # Build a sortable list: "score:name" lines, then sort numerically
    local priority_list=""
    priority_list="${priority_list}${score_1}:${name_1}
${score_2}:${name_2}
${score_3}:${name_3}
${score_4}:${name_4}
${score_5}:${name_5}
${score_6}:${name_6}
${score_7}:${name_7}
${score_8}:${name_8}"

    local sorted_list
    sorted_list=$(echo "$priority_list" | sort -t: -k1 -n)

    local found_priority=false
    echo "$sorted_list" | while read -r entry; do
        if [ -z "$entry" ]; then continue; fi
        local escore ename
        escore=$(echo "$entry" | cut -d: -f1)
        ename=$(echo "$entry" | cut -d: -f2)

        if [ "$escore" -lt 75 ] 2>/dev/null; then
            found_priority=true
            local eemoji
            eemoji=$(get_rating_emoji "$escore")

            echo "$eemoji **$ename** (${escore}/100):"

            # Provide category-specific recommendations
            case "$ename" in
                Nodes)
                    lang_get_block "recommend_nodes"
                    ;;
                Workloads)
                    lang_get_block "recommend_workloads"
                    ;;
                Resources)
                    lang_get_block "recommend_resources"
                    ;;
                Security)
                    lang_get_block "recommend_security"
                    ;;
                Storage)
                    lang_get_block "recommend_storage"
                    ;;
                Events)
                    lang_get_block "recommend_events"
                    ;;
                Networking)
                    lang_get_block "recommend_networking"
                    ;;
                Config)
                    lang_get_block "recommend_config"
                    ;;
            esac
            echo ""
        fi
    done

    # Check if any priorities were found (subshell issue workaround)
    local any_below=false
    local check_line
    for check_line in $cat_scores; do
        if [ "$check_line" -lt 75 ] 2>/dev/null; then
            any_below=true
            break
        fi
    done
    if [ "$any_below" = false ]; then
        echo "All categories are scoring 75 or above. Keep up the good work!"
        echo ""
    fi

    echo ""
    echo "---"
}
