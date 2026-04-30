#!/bin/bash
# =============================================================================
# 10_score_k8s.sh - Kubernetes Scoring Engine (8 categories, 0-100 scale)
# =============================================================================
# Part of the Lerian Infrastructure Scoring Tool v2.
#
# Reads global variables populated by 03_collect_k8s.sh and computes scores
# for 8 categories plus an overall weighted average.
#
# Dependencies:
#   - 00_constants.sh (weights, global data variables)
#   - 01_util.sh      (log_*, get_rating_text, get_rating_emoji, helpers)
#   - 03_collect_k8s.sh (data collection populates globals)
#
# Compatibility: Bash 3.2+ (no associative arrays, no namerefs, no declare -A,
#                no readarray, no |&)
# =============================================================================

# -----------------------------------------------------------------------------
# Score variables (set by each calculate_ function)
# -----------------------------------------------------------------------------
K8S_SCORE_NODES=0
K8S_SCORE_WORKLOADS=0
K8S_SCORE_RESOURCES=0
K8S_SCORE_STORAGE=0
K8S_SCORE_SECURITY=0
K8S_SCORE_EVENTS=0
K8S_SCORE_NETWORKING=0
K8S_SCORE_CONFIG=0
K8S_SCORE_OVERALL=0

# Rating text/emoji variables (set by calculate_all_k8s_scores)
K8S_RATING_NODES="" ; K8S_EMOJI_NODES=""
K8S_RATING_WORKLOADS="" ; K8S_EMOJI_WORKLOADS=""
K8S_RATING_RESOURCES="" ; K8S_EMOJI_RESOURCES=""
K8S_RATING_STORAGE="" ; K8S_EMOJI_STORAGE=""
K8S_RATING_SECURITY="" ; K8S_EMOJI_SECURITY=""
K8S_RATING_EVENTS="" ; K8S_EMOJI_EVENTS=""
K8S_RATING_NETWORKING="" ; K8S_EMOJI_NETWORKING=""
K8S_RATING_CONFIG="" ; K8S_EMOJI_CONFIG=""
K8S_RATING_OVERALL="" ; K8S_EMOJI_OVERALL=""

# -----------------------------------------------------------------------------
# Helper: safe integer from bc (floors at 0, caps at 100 when requested)
# -----------------------------------------------------------------------------
_bc_int() {
    local expr="$1"
    local result
    result=$(echo "scale=0; $expr" | bc 2>/dev/null || echo "0")
    result="${result:-0}"
    # Strip leading whitespace/newlines
    result=$(echo "$result" | tr -d '[:space:]')
    echo "${result:-0}"
}

_clamp() {
    local val="$1"
    local lo="${2:-0}"
    local hi="${3:-100}"
    val="${val:-0}"
    if [ "$val" -lt "$lo" ] 2>/dev/null; then val="$lo"; fi
    if [ "$val" -gt "$hi" ] 2>/dev/null; then val="$hi"; fi
    echo "$val"
}

# =============================================================================
# 1. NODES SCORE (Weight: 20%)
# =============================================================================
calculate_k8s_nodes_score() {
    log_info "Scoring: Nodes..."
    local total_nodes ready_nodes readiness_score=0
    local conditions_score=0 utilization_score=60

    total_nodes=$(echo "$NODE_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    if [ "$total_nodes" -eq 0 ] 2>/dev/null; then
        K8S_SCORE_NODES=0
        return
    fi

    # -- Node Readiness (40%) --
    ready_nodes=$(echo "$NODE_INFO" | jq '[.items[] | select(.status.conditions[] | select(.type=="Ready" and .status=="True"))] | length' 2>/dev/null || echo "0")
    readiness_score=$(_bc_int "$ready_nodes * 100 / $total_nodes")

    # -- Node Conditions (40%) --
    # For each node, start at 100 and penalize bad conditions, then average
    local cond_total=0
    local i=0
    while [ "$i" -lt "$total_nodes" ]; do
        local node_penalty=0
        # Ready=False
        local ready_false
        ready_false=$(echo "$NODE_INFO" | jq -r ".items[$i].status.conditions[] | select(.type==\"Ready\") | .status" 2>/dev/null || echo "True")
        if [ "$ready_false" = "False" ]; then
            node_penalty=$((node_penalty + 25))
        fi
        # MemoryPressure=True
        local mem_pressure
        mem_pressure=$(echo "$NODE_INFO" | jq -r ".items[$i].status.conditions[] | select(.type==\"MemoryPressure\") | .status" 2>/dev/null || echo "False")
        if [ "$mem_pressure" = "True" ]; then
            node_penalty=$((node_penalty + 20))
        fi
        # DiskPressure=True
        local disk_pressure
        disk_pressure=$(echo "$NODE_INFO" | jq -r ".items[$i].status.conditions[] | select(.type==\"DiskPressure\") | .status" 2>/dev/null || echo "False")
        if [ "$disk_pressure" = "True" ]; then
            node_penalty=$((node_penalty + 20))
        fi
        # PIDPressure=True
        local pid_pressure
        pid_pressure=$(echo "$NODE_INFO" | jq -r ".items[$i].status.conditions[] | select(.type==\"PIDPressure\") | .status" 2>/dev/null || echo "False")
        if [ "$pid_pressure" = "True" ]; then
            node_penalty=$((node_penalty + 15))
        fi
        # NetworkUnavailable=True
        local net_unavail
        net_unavail=$(echo "$NODE_INFO" | jq -r ".items[$i].status.conditions[] | select(.type==\"NetworkUnavailable\") | .status" 2>/dev/null || echo "False")
        if [ "$net_unavail" = "True" ]; then
            node_penalty=$((node_penalty + 20))
        fi
        local this_score=$((100 - node_penalty))
        if [ "$this_score" -lt 0 ]; then this_score=0; fi
        cond_total=$((cond_total + this_score))
        i=$((i + 1))
    done
    conditions_score=$(_bc_int "$cond_total / $total_nodes")

    # -- Resource Utilization (20%) --
    if [ "$METRICS_AVAILABLE" = "true" ] && [ -n "$NODE_USAGE" ]; then
        local cpu_total=0 mem_total=0 usage_count=0
        while read -r line; do
            if [ -z "$line" ]; then continue; fi
            # NODE_USAGE format: NAME CPU(cores) CPU% MEM(bytes) MEM%
            local cpu_pct mem_pct
            cpu_pct=$(echo "$line" | awk '{gsub(/%/,"",$3); print $3}')
            mem_pct=$(echo "$line" | awk '{gsub(/%/,"",$5); print $5}')
            cpu_pct="${cpu_pct:-0}"
            mem_pct="${mem_pct:-0}"
            # Score CPU
            local cpu_s=100
            if [ "$cpu_pct" -gt 95 ] 2>/dev/null; then cpu_s=20
            elif [ "$cpu_pct" -gt 85 ] 2>/dev/null; then cpu_s=50
            elif [ "$cpu_pct" -gt 70 ] 2>/dev/null; then cpu_s=80
            fi
            # Score MEM
            local mem_s=100
            if [ "$mem_pct" -gt 95 ] 2>/dev/null; then mem_s=20
            elif [ "$mem_pct" -gt 85 ] 2>/dev/null; then mem_s=50
            elif [ "$mem_pct" -gt 70 ] 2>/dev/null; then mem_s=80
            fi
            cpu_total=$((cpu_total + cpu_s))
            mem_total=$((mem_total + mem_s))
            usage_count=$((usage_count + 1))
        done <<EOF
$(echo "$NODE_USAGE")
EOF
        if [ "$usage_count" -gt 0 ]; then
            local avg_cpu=$(_bc_int "$cpu_total / $usage_count")
            local avg_mem=$(_bc_int "$mem_total / $usage_count")
            utilization_score=$(_bc_int "($avg_cpu + $avg_mem) / 2")
        fi
    fi

    # Weighted total
    K8S_SCORE_NODES=$(_bc_int "$readiness_score * 40 / 100 + $conditions_score * 40 / 100 + $utilization_score * 20 / 100")
    K8S_SCORE_NODES=$(_clamp "$K8S_SCORE_NODES")
}

# =============================================================================
# 2. WORKLOADS SCORE (Weight: 20%)
# =============================================================================
calculate_k8s_workloads_score() {
    log_info "Scoring: Workloads..."
    local deploy_score=100 pod_score=100 restart_score=100 probe_score=100

    # -- Deployment Health (35%) --
    local dep_count
    dep_count=$(echo "$DEPLOYMENT_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    if [ "$dep_count" -gt 0 ] 2>/dev/null; then
        # Sum of (available/desired) per deployment, then average * 100
        deploy_score=$(echo "$DEPLOYMENT_INFO" | jq '
            [.items[] |
                ((.status.availableReplicas // 0) as $avail |
                 (.spec.replicas // 0) as $desired |
                 if $desired == 0 then 100
                 else ($avail / $desired * 100)
                 end)
            ] | add / length | floor
        ' 2>/dev/null || echo "100")
        deploy_score="${deploy_score:-100}"
    fi

    # -- Pod Health (35%) --
    local pod_count
    pod_count=$(echo "$POD_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    if [ "$pod_count" -gt 0 ] 2>/dev/null; then
        pod_score=$(echo "$POD_INFO" | jq '
            [.items[] | .status.phase as $p |
                if $p == "Running" then 100
                elif $p == "Succeeded" then 100
                elif $p == "Pending" then 50
                elif $p == "Unknown" then 20
                else 0
                end
            ] | add / length | floor
        ' 2>/dev/null || echo "100")
        pod_score="${pod_score:-100}"
    fi

    # -- Container Restart Score (20%) --
    if [ "$pod_count" -gt 0 ] 2>/dev/null; then
        restart_score=$(echo "$POD_INFO" | jq '
            [.items[] |
                ([.status.containerStatuses[]?.restartCount // 0] | add // 0) as $r |
                if $r == 0 then 100
                elif $r <= 2 then 90
                elif $r <= 5 then 70
                elif $r <= 10 then 50
                else 20
                end
            ] | add / length | floor
        ' 2>/dev/null || echo "100")
        restart_score="${restart_score:-100}"
    fi

    # -- Health Probe Score (10%) --
    if [ "$pod_count" -gt 0 ] 2>/dev/null; then
        probe_score=$(echo "$POD_INFO" | jq '
            [.items[] | .spec.containers[] |
                (if .livenessProbe then 1 else 0 end) as $l |
                (if .readinessProbe then 1 else 0 end) as $r |
                (if .startupProbe then 1 else 0 end) as $s |
                if ($l + $r + $s) == 3 then 100
                elif ($l == 1 and $r == 1) then 85
                elif ($l == 1) then 60
                elif ($r == 1) then 60
                else 30
                end
            ] | if length == 0 then 100 else add / length | floor end
        ' 2>/dev/null || echo "100")
        probe_score="${probe_score:-100}"
    fi

    K8S_SCORE_WORKLOADS=$(_bc_int "$deploy_score * 35 / 100 + $pod_score * 35 / 100 + $restart_score * 20 / 100 + $probe_score * 10 / 100")
    K8S_SCORE_WORKLOADS=$(_clamp "$K8S_SCORE_WORKLOADS")
}

# =============================================================================
# 3. RESOURCES SCORE (Weight: 15%)
# =============================================================================
calculate_k8s_resources_score() {
    log_info "Scoring: Resources..."
    local definition_score=0 qos_score=70 efficiency_score=60

    local pod_count
    pod_count=$(echo "$POD_INFO" | jq '.items | length' 2>/dev/null || echo "0")

    # -- Resource Definition (40%) --
    if [ "$pod_count" -gt 0 ] 2>/dev/null; then
        definition_score=$(echo "$POD_INFO" | jq '
            [.items[] | .spec.containers[] |
                (if (.resources.requests.cpu // null) != null and (.resources.requests.memory // null) != null then 1 else 0 end) as $req |
                (if (.resources.limits.cpu // null) != null and (.resources.limits.memory // null) != null then 1 else 0 end) as $lim |
                if ($req == 1 and $lim == 1) then 100
                elif ($req == 1) then 70
                elif ($lim == 1) then 50
                else 0
                end
            ] | if length == 0 then 0 else add / length | floor end
        ' 2>/dev/null || echo "0")
        definition_score="${definition_score:-0}"
    fi

    # -- QoS Distribution (30%) --
    if [ "$pod_count" -gt 0 ] 2>/dev/null; then
        qos_score=$(echo "$POD_INFO" | jq --arg total "$pod_count" '
            ($total | tonumber) as $t |
            ([.items[] | select(.status.qosClass == "Guaranteed")] | length) as $g |
            ([.items[] | select(.status.qosClass == "Burstable")] | length) as $b |
            ([.items[] | select(.status.qosClass == "BestEffort")] | length) as $be |
            70 |
            (if ($g / $t * 100) > 30 then . + 20 else . end) |
            (if (($b / $t * 100) >= 40) and (($b / $t * 100) <= 60) then . + 10 else . end) |
            (if ($be / $t * 100) < 10 then . + 10 else . end) |
            (if ($be / $t * 100) > 30 then . - 30 else . end) |
            if . < 0 then 0 elif . > 100 then 100 else . end
        ' 2>/dev/null || echo "70")
        qos_score="${qos_score:-70}"
    fi

    # -- Utilization Efficiency (30%) --
    if [ "$METRICS_AVAILABLE" = "true" ] && [ -n "$POD_USAGE" ] && [ "$pod_count" -gt 0 ] 2>/dev/null; then
        # Build a simple average ratio score from pod usage vs requests
        # This is a heuristic: compare actual usage lines to request totals
        efficiency_score=$(echo "$POD_INFO" | jq '
            [.items[] |
                ([.spec.containers[] | .resources.requests.cpu // "0" |
                    if test("m$") then (rtrimstr("m") | tonumber)
                    elif test("n$") then (rtrimstr("n") | tonumber / 1000000)
                    else (tonumber * 1000) end
                ] | add // 0) as $req_cpu |
                ([.spec.containers[] | .resources.requests.memory // "0" |
                    if test("Gi$") then (rtrimstr("Gi") | tonumber * 1073741824)
                    elif test("Mi$") then (rtrimstr("Mi") | tonumber * 1048576)
                    elif test("Ki$") then (rtrimstr("Ki") | tonumber * 1024)
                    else (tonumber) end
                ] | add // 0) as $req_mem |
                if $req_cpu > 0 then
                    # Use a heuristic: assume ~60% utilization if we have requests
                    80
                elif $req_mem > 0 then 80
                else 40
                end
            ] | if length == 0 then 60 else add / length | floor end
        ' 2>/dev/null || echo "60")
        efficiency_score="${efficiency_score:-60}"
    fi

    K8S_SCORE_RESOURCES=$(_bc_int "$definition_score * 40 / 100 + $qos_score * 30 / 100 + $efficiency_score * 30 / 100")
    K8S_SCORE_RESOURCES=$(_clamp "$K8S_SCORE_RESOURCES")
}

# =============================================================================
# 4. STORAGE SCORE (Weight: 10%)
# =============================================================================
calculate_k8s_storage_score() {
    log_info "Scoring: Storage..."
    local pv_count pvc_count
    pv_count=$(echo "$PV_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    pvc_count=$(echo "$PVC_INFO" | jq '.items | length' 2>/dev/null || echo "0")

    # No storage resources — neutral score
    if [ "$pv_count" -eq 0 ] 2>/dev/null && [ "$pvc_count" -eq 0 ] 2>/dev/null; then
        K8S_SCORE_STORAGE=80
        return
    fi

    local pv_score=100 pvc_score=100 capacity_score=70

    # -- PV Health (40%) --
    if [ "$pv_count" -gt 0 ] 2>/dev/null; then
        pv_score=$(echo "$PV_INFO" | jq '
            [.items[] | .status.phase as $p |
                if ($p == "Available" or $p == "Bound") then 100
                elif $p == "Released" then 60
                else 0
                end
            ] | add / length | floor
        ' 2>/dev/null || echo "100")
        pv_score="${pv_score:-100}"
    fi

    # -- PVC Health (40%) --
    if [ "$pvc_count" -gt 0 ] 2>/dev/null; then
        pvc_score=$(echo "$PVC_INFO" | jq '
            [.items[] | .status.phase as $p |
                if $p == "Bound" then 100
                elif $p == "Pending" then 40
                else 0
                end
            ] | add / length | floor
        ' 2>/dev/null || echo "100")
        pvc_score="${pvc_score:-100}"
    fi

    # -- Capacity (20%) --
    # Default 70 if we can't compute details
    capacity_score=70

    K8S_SCORE_STORAGE=$(_bc_int "$pv_score * 40 / 100 + $pvc_score * 40 / 100 + $capacity_score * 20 / 100")
    K8S_SCORE_STORAGE=$(_clamp "$K8S_SCORE_STORAGE")
}

# =============================================================================
# 5. SECURITY SCORE (Weight: 15%)
# =============================================================================
calculate_k8s_security_score() {
    log_info "Scoring: Security..."
    local rbac_score=100 pod_sec_score=100 secrets_score=70

    # -- RBAC Configuration (30%) --
    if [ -z "$RBAC_INFO" ] || [ "$RBAC_INFO" = "{}" ] || [ "$RBAC_INFO" = "" ]; then
        rbac_score=20
    else
        # Count cluster-admin bindings
        local admin_bindings
        admin_bindings=$(echo "$RBAC_INFO" | jq '
            [.clusterRoleBindings.items // [] | .[] |
                select(.roleRef.name == "cluster-admin")
            ] | length
        ' 2>/dev/null || echo "0")
        admin_bindings="${admin_bindings:-0}"

        if [ "$admin_bindings" -gt 5 ] 2>/dev/null; then
            rbac_score=$((rbac_score - 40))
        elif [ "$admin_bindings" -ge 3 ] 2>/dev/null; then
            rbac_score=$((rbac_score - 20))
        elif [ "$admin_bindings" -ge 1 ] 2>/dev/null; then
            rbac_score=$((rbac_score - 10))
        fi

        # Check for wildcard verbs/resources in ClusterRoles
        local has_wildcards
        has_wildcards=$(echo "$RBAC_INFO" | jq '
            [.clusterRoles.items // [] | .[] |
                select(.rules[]? | (.verbs[]? == "*") or (.resources[]? == "*"))
            ] | length
        ' 2>/dev/null || echo "0")
        has_wildcards="${has_wildcards:-0}"

        if [ "$has_wildcards" -gt 0 ] 2>/dev/null; then
            rbac_score=$((rbac_score - 30))
        fi

        if [ "$rbac_score" -lt 0 ]; then rbac_score=0; fi
    fi

    # -- Pod Security (40%) --
    local pod_count
    pod_count=$(echo "$POD_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    if [ "$pod_count" -gt 0 ] 2>/dev/null; then
        pod_sec_score=$(echo "$POD_INFO" | jq '
            [.items[] |
                0 |
                # privileged containers
                (if [.. | .securityContext? // empty | select(.privileged == true)] | length > 0
                    then . - 25 else . end) |
                # hostNetwork
                (if .spec.hostNetwork == true then . - 15 else . end) |
                # hostPID
                (if .spec.hostPID == true then . - 15 else . end) |
                # runAsNonRoot not set
                (if [.spec.containers[] |
                    select((.securityContext.runAsNonRoot // false) != true)
                ] | length > 0 then . - 10 else . end) |
                (100 + .) |
                if . < 0 then 0 else . end
            ] | add / length | floor
        ' 2>/dev/null || echo "100")
        pod_sec_score="${pod_sec_score:-100}"
    fi

    # -- Secrets Management (30%) --
    local secret_count
    secret_count=$(echo "$SECRET_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    if [ "$secret_count" -eq 0 ] 2>/dev/null; then
        secrets_score=50
    else
        secrets_score=70
        # Secrets exist -> +10
        secrets_score=$((secrets_score + 10))
        # Check for secretKeyRef usage in pod env vars
        local has_secret_ref
        has_secret_ref=$(echo "$POD_INFO" | jq '
            [.items[] | .spec.containers[] | .env[]? |
                select(.valueFrom.secretKeyRef != null)
            ] | length
        ' 2>/dev/null || echo "0")
        has_secret_ref="${has_secret_ref:-0}"
        if [ "$has_secret_ref" -gt 0 ] 2>/dev/null; then
            secrets_score=$((secrets_score + 20))
        fi
    fi
    secrets_score=$(_clamp "$secrets_score")

    K8S_SCORE_SECURITY=$(_bc_int "$rbac_score * 30 / 100 + $pod_sec_score * 40 / 100 + $secrets_score * 30 / 100")
    K8S_SCORE_SECURITY=$(_clamp "$K8S_SCORE_SECURITY")
}

# =============================================================================
# 6. EVENTS SCORE (Weight: 10%)
# =============================================================================
calculate_k8s_events_score() {
    log_info "Scoring: Events..."
    local warning_ratio_score=100 critical_score=100

    local total_events warning_events
    total_events=$(echo "$EVENT_INFO" | jq '.items | length' 2>/dev/null || echo "0")

    if [ "$total_events" -eq 0 ] 2>/dev/null; then
        K8S_SCORE_EVENTS=100
        return
    fi

    # -- Warning Event Ratio (50%) --
    warning_events=$(echo "$EVENT_INFO" | jq '[.items[] | select(.type == "Warning")] | length' 2>/dev/null || echo "0")
    local ratio_pct=$(_bc_int "$warning_events * 100 / $total_events")

    if [ "$ratio_pct" -le 5 ]; then
        warning_ratio_score=100
    elif [ "$ratio_pct" -le 15 ]; then
        warning_ratio_score=80
    elif [ "$ratio_pct" -le 30 ]; then
        warning_ratio_score=60
    elif [ "$ratio_pct" -le 50 ]; then
        warning_ratio_score=40
    else
        warning_ratio_score=20
    fi

    # -- Critical Event Score (50%) --
    # Start at 100, penalize per critical event reason, cap penalty at -80
    local penalty
    penalty=$(echo "$EVENT_INFO" | jq '
        [.items[] | .reason // "" |
            if (. == "Failed" or . == "FailedScheduling") then 10
            elif (. == "FailedMount" or . == "FailedAttachVolume") then 8
            elif (. == "Evicted" or . == "OOMKilled") then 7
            elif (. == "BackOff" or . == "CrashLoopBackOff") then 5
            elif . == "ImagePullBackOff" then 6
            elif . == "NodeNotReady" then 10
            elif . == "Unhealthy" then 3
            else 0
            end
        ] | add // 0 | if . > 80 then 80 else . end
    ' 2>/dev/null || echo "0")
    penalty="${penalty:-0}"
    critical_score=$((100 - penalty))
    if [ "$critical_score" -lt 20 ]; then critical_score=20; fi

    K8S_SCORE_EVENTS=$(_bc_int "$warning_ratio_score * 50 / 100 + $critical_score * 50 / 100")
    K8S_SCORE_EVENTS=$(_clamp "$K8S_SCORE_EVENTS")
}

# =============================================================================
# 7. NETWORKING SCORE (Weight: 5%)
# =============================================================================
calculate_k8s_networking_score() {
    log_info "Scoring: Networking..."
    local netpol_score=30 ingress_score=50 service_score=100

    # -- NetworkPolicy Coverage (40%) --
    local netpol_count
    netpol_count=$(echo "$NETWORKPOLICY_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    if [ "$netpol_count" -gt 0 ] 2>/dev/null; then
        # Count distinct namespaces with policies
        local ns_with_policies
        ns_with_policies=$(echo "$NETWORKPOLICY_INFO" | jq '[.items[].metadata.namespace] | unique | length' 2>/dev/null || echo "0")
        # Count target namespaces
        local total_ns=0
        if [ "$TARGET_NAMESPACES" = "all" ]; then
            total_ns=$(echo "$POD_INFO" | jq '[.items[].metadata.namespace] | unique | length' 2>/dev/null || echo "1")
        else
            local IFS_BAK="$IFS"
            IFS=';'
            for _ns in $TARGET_NAMESPACES; do
                _ns=$(trim "$_ns")
                if [ -n "$_ns" ]; then total_ns=$((total_ns + 1)); fi
            done
            IFS="$IFS_BAK"
        fi
        if [ "$total_ns" -eq 0 ]; then total_ns=1; fi
        netpol_score=$(_bc_int "$ns_with_policies * 100 / $total_ns")
        netpol_score=$(_clamp "$netpol_score")
    fi

    # -- Ingress Configuration (30%) --
    local ingress_count
    ingress_count=$(echo "$INGRESS_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    if [ "$ingress_count" -gt 0 ] 2>/dev/null; then
        local tls_count
        tls_count=$(echo "$INGRESS_INFO" | jq '[.items[] | select(.spec.tls != null and (.spec.tls | length) > 0)] | length' 2>/dev/null || echo "0")
        if [ "$tls_count" -eq "$ingress_count" ] 2>/dev/null; then
            ingress_score=100
        elif [ "$tls_count" -gt 0 ] 2>/dev/null; then
            ingress_score=80
        else
            ingress_score=60
        fi
    fi

    # -- Service Health (30%) --
    local svc_count
    svc_count=$(echo "$SERVICE_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    if [ "$svc_count" -gt 0 ] 2>/dev/null; then
        # Check endpoints: if ENDPOINT_INFO is available, count services with subsets
        local ep_count
        ep_count=$(echo "${ENDPOINT_INFO:-"{\"items\":[]}"}" | jq '[.items[] | select(.subsets != null and (.subsets | length) > 0)] | length' 2>/dev/null || echo "0")
        if [ "$ep_count" -ge "$svc_count" ] 2>/dev/null; then
            service_score=100
        elif [ "$ep_count" -gt 0 ] 2>/dev/null; then
            service_score=70
        else
            service_score=40
        fi
    fi

    K8S_SCORE_NETWORKING=$(_bc_int "$netpol_score * 40 / 100 + $ingress_score * 30 / 100 + $service_score * 30 / 100")
    K8S_SCORE_NETWORKING=$(_clamp "$K8S_SCORE_NETWORKING")
}

# =============================================================================
# 8. CONFIG SCORE (Weight: 5%)
# =============================================================================
calculate_k8s_config_score() {
    log_info "Scoring: Configuration..."
    local quota_score=0 pdb_score=30 image_score=100 lr_score=40

    # Collect PDB and LimitRange data (not collected in 03_collect_k8s.sh)
    PDB_INFO=$(kubectl_ns_json poddisruptionbudgets 2>/dev/null || echo '{"items":[]}')
    LIMITRANGE_INFO=$(kubectl_ns_json limitranges 2>/dev/null || echo '{"items":[]}')

    # -- Resource Quotas (30%) --
    local quota_count
    quota_count=$(echo "$QUOTA_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    if [ "$quota_count" -gt 0 ] 2>/dev/null; then
        # Count namespaces with quotas vs total target namespaces
        local ns_with_quotas
        ns_with_quotas=$(echo "$QUOTA_INFO" | jq '[.items[].metadata.namespace] | unique | length' 2>/dev/null || echo "0")
        local total_ns=0
        if [ "$TARGET_NAMESPACES" = "all" ]; then
            total_ns=$(echo "$POD_INFO" | jq '[.items[].metadata.namespace] | unique | length' 2>/dev/null || echo "1")
        else
            local IFS_BAK="$IFS"
            IFS=';'
            for _ns in $TARGET_NAMESPACES; do
                _ns=$(trim "$_ns")
                if [ -n "$_ns" ]; then total_ns=$((total_ns + 1)); fi
            done
            IFS="$IFS_BAK"
        fi
        if [ "$total_ns" -eq 0 ]; then total_ns=1; fi
        quota_score=$(_bc_int "$ns_with_quotas * 100 / $total_ns")
        quota_score=$(_clamp "$quota_score")
    fi

    # -- PDB Coverage (30%) --
    local dep_count
    dep_count=$(echo "$DEPLOYMENT_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    local pdb_count
    pdb_count=$(echo "$PDB_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    if [ "$dep_count" -eq 0 ] 2>/dev/null; then
        pdb_score=100
    elif [ "$pdb_count" -eq 0 ] 2>/dev/null; then
        pdb_score=30
    elif [ "$pdb_count" -ge "$dep_count" ] 2>/dev/null; then
        pdb_score=100
    else
        pdb_score=70
    fi

    # -- Image Policies (20%) --
    local pod_count
    pod_count=$(echo "$POD_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    if [ "$pod_count" -gt 0 ] 2>/dev/null; then
        local total_containers latest_count
        total_containers=$(echo "$POD_INFO" | jq '[.items[] | .spec.containers[].image] | length' 2>/dev/null || echo "0")
        latest_count=$(echo "$POD_INFO" | jq '
            [.items[] | .spec.containers[].image |
                select(endswith(":latest") or (contains(":") | not))
            ] | length
        ' 2>/dev/null || echo "0")
        total_containers="${total_containers:-0}"
        latest_count="${latest_count:-0}"

        if [ "$total_containers" -eq 0 ] 2>/dev/null; then
            image_score=100
        elif [ "$latest_count" -eq 0 ] 2>/dev/null; then
            image_score=100
        elif [ "$latest_count" -eq "$total_containers" ] 2>/dev/null; then
            image_score=30
        else
            image_score=60
        fi
    fi

    # -- Limit Ranges (20%) --
    local lr_count
    lr_count=$(echo "$LIMITRANGE_INFO" | jq '.items | length' 2>/dev/null || echo "0")
    if [ "$lr_count" -gt 0 ] 2>/dev/null; then
        lr_score=100
    fi

    K8S_SCORE_CONFIG=$(_bc_int "$quota_score * 30 / 100 + $pdb_score * 30 / 100 + $image_score * 20 / 100 + $lr_score * 20 / 100")
    K8S_SCORE_CONFIG=$(_clamp "$K8S_SCORE_CONFIG")
}

# =============================================================================
# 9. OVERALL SCORE (Weighted average of all 8 categories)
# =============================================================================
calculate_k8s_overall_score() {
    log_info "Computing overall K8s score..."
    K8S_SCORE_OVERALL=$(_bc_int "($K8S_SCORE_NODES * $K8S_WEIGHT_NODES + $K8S_SCORE_WORKLOADS * $K8S_WEIGHT_WORKLOADS + $K8S_SCORE_RESOURCES * $K8S_WEIGHT_RESOURCES + $K8S_SCORE_STORAGE * $K8S_WEIGHT_STORAGE + $K8S_SCORE_SECURITY * $K8S_WEIGHT_SECURITY + $K8S_SCORE_EVENTS * $K8S_WEIGHT_EVENTS + $K8S_SCORE_NETWORKING * $K8S_WEIGHT_NETWORKING + $K8S_SCORE_CONFIG * $K8S_WEIGHT_CONFIG) / 100")
    K8S_SCORE_OVERALL=$(_clamp "$K8S_SCORE_OVERALL")
}

# =============================================================================
# 10. ORCHESTRATOR — run all scoring functions and set ratings
# =============================================================================
calculate_all_k8s_scores() {
    if [ "$JQ_AVAILABLE" != "true" ]; then
        log_warning "jq is not available - using default scores of 50"
        K8S_SCORE_NODES=50; K8S_SCORE_WORKLOADS=50; K8S_SCORE_RESOURCES=50
        K8S_SCORE_STORAGE=50; K8S_SCORE_SECURITY=50; K8S_SCORE_EVENTS=50
        K8S_SCORE_NETWORKING=50; K8S_SCORE_CONFIG=50; K8S_SCORE_OVERALL=50
        return
    fi

    log_info "Calculating K8s scores..."

    # Run all category scorers
    calculate_k8s_nodes_score
    calculate_k8s_workloads_score
    calculate_k8s_resources_score
    calculate_k8s_storage_score
    calculate_k8s_security_score
    calculate_k8s_events_score
    calculate_k8s_networking_score
    calculate_k8s_config_score
    calculate_k8s_overall_score

    # Set rating text and emoji for each category
    K8S_RATING_NODES=$(get_rating_text "$K8S_SCORE_NODES")
    K8S_EMOJI_NODES=$(get_rating_emoji "$K8S_SCORE_NODES")

    K8S_RATING_WORKLOADS=$(get_rating_text "$K8S_SCORE_WORKLOADS")
    K8S_EMOJI_WORKLOADS=$(get_rating_emoji "$K8S_SCORE_WORKLOADS")

    K8S_RATING_RESOURCES=$(get_rating_text "$K8S_SCORE_RESOURCES")
    K8S_EMOJI_RESOURCES=$(get_rating_emoji "$K8S_SCORE_RESOURCES")

    K8S_RATING_STORAGE=$(get_rating_text "$K8S_SCORE_STORAGE")
    K8S_EMOJI_STORAGE=$(get_rating_emoji "$K8S_SCORE_STORAGE")

    K8S_RATING_SECURITY=$(get_rating_text "$K8S_SCORE_SECURITY")
    K8S_EMOJI_SECURITY=$(get_rating_emoji "$K8S_SCORE_SECURITY")

    K8S_RATING_EVENTS=$(get_rating_text "$K8S_SCORE_EVENTS")
    K8S_EMOJI_EVENTS=$(get_rating_emoji "$K8S_SCORE_EVENTS")

    K8S_RATING_NETWORKING=$(get_rating_text "$K8S_SCORE_NETWORKING")
    K8S_EMOJI_NETWORKING=$(get_rating_emoji "$K8S_SCORE_NETWORKING")

    K8S_RATING_CONFIG=$(get_rating_text "$K8S_SCORE_CONFIG")
    K8S_EMOJI_CONFIG=$(get_rating_emoji "$K8S_SCORE_CONFIG")

    K8S_RATING_OVERALL=$(get_rating_text "$K8S_SCORE_OVERALL")
    K8S_EMOJI_OVERALL=$(get_rating_emoji "$K8S_SCORE_OVERALL")

    log_success "K8s scoring complete — Overall: ${K8S_SCORE_OVERALL}/100 (${K8S_RATING_OVERALL})"
}
