#!/bin/bash
# =============================================================================
# 14_score_rabbit.sh - RabbitMQ Health Scoring (0-100 scale)
# =============================================================================
# 8 categories weighted per methodology doc:
#   Queue Health 20%, Message Flow & Throughput 20%, Node Resources 15%,
#   Cluster Health 15%, Connection & Channel Health 10%, Security 10%,
#   Persistence & Durability 5%, Configuration Best Practices 5%
#
# Compatibility: Bash 3.2+ (no associative arrays, no namerefs)
# =============================================================================

# -----------------------------------------------------------------------------
# Score variables (set by each _rmq_score_* function)
# -----------------------------------------------------------------------------
RMQ_SCORE_QUEUES=0
RMQ_SCORE_FLOW=0
RMQ_SCORE_RESOURCES=0
RMQ_SCORE_CLUSTER=0
RMQ_SCORE_CONNECTIONS=0
RMQ_SCORE_SECURITY=0
RMQ_SCORE_PERSISTENCE=0
RMQ_SCORE_CONFIG=0

# Per-category rating text/emoji
RMQ_RATING_QUEUES=""       ; RMQ_EMOJI_QUEUES=""
RMQ_RATING_FLOW=""         ; RMQ_EMOJI_FLOW=""
RMQ_RATING_RESOURCES=""    ; RMQ_EMOJI_RESOURCES=""
RMQ_RATING_CLUSTER=""      ; RMQ_EMOJI_CLUSTER=""
RMQ_RATING_CONNECTIONS=""  ; RMQ_EMOJI_CONNECTIONS=""
RMQ_RATING_SECURITY=""     ; RMQ_EMOJI_SECURITY=""
RMQ_RATING_PERSISTENCE=""  ; RMQ_EMOJI_PERSISTENCE=""
RMQ_RATING_CONFIG=""       ; RMQ_EMOJI_CONFIG=""

# =============================================================================
# 1. QUEUE HEALTH (Weight: 20%)
# =============================================================================
# Formula from doc section 4.1.3:
#   Queue Health = Depth*0.30 + ConsumerBalance*0.25 + GrowthRate*0.20
#                  + Unacked*0.15 + QueueMemory*0.10
# =============================================================================
_rmq_score_queues() {
    local total_queues
    total_queues=$(echo "$RMQ_QUEUES_DATA" | jq 'length' 2>/dev/null || echo "0")
    if [ "$total_queues" -eq 0 ] 2>/dev/null; then
        echo 80  # No queues — idle broker is acceptable
        return
    fi

    # --- A. Queue Depth (30%) ---
    local max_depth
    max_depth=$(echo "$RMQ_QUEUES_DATA" | jq '[.[].messages_ready // 0] | max // 0' 2>/dev/null || echo "0")
    max_depth=$(printf "%.0f" "$max_depth" 2>/dev/null || echo "0")

    local depth_score=100
    if [ "$max_depth" -gt 1000000 ]; then depth_score=25
    elif [ "$max_depth" -gt 100000 ]; then depth_score=50
    elif [ "$max_depth" -gt 10000 ]; then depth_score=70
    elif [ "$max_depth" -gt 1000 ]; then depth_score=85
    fi

    # --- B. Consumer Balance (25%) ---
    # Queues with 0 consumers AND messages > 0
    local no_consumer_queues
    no_consumer_queues=$(echo "$RMQ_QUEUES_DATA" | jq '[.[] | select(.consumers == 0 and (.messages // 0) > 0)] | length' 2>/dev/null || echo "0")

    local consumer_score=100
    if [ "$no_consumer_queues" -gt 10 ]; then consumer_score=20
    elif [ "$no_consumer_queues" -gt 5 ]; then consumer_score=40
    elif [ "$no_consumer_queues" -gt 2 ]; then consumer_score=60
    elif [ "$no_consumer_queues" -gt 0 ]; then consumer_score=80
    fi

    # Secondary check: consumerless queues even if empty (latent risk)
    if [ "$no_consumer_queues" -eq 0 ] 2>/dev/null; then
        local all_consumerless total_q_count consumerless_pct
        all_consumerless=$(echo "$RMQ_QUEUES_DATA" | jq '[.[] | select(.consumers == 0)] | length' 2>/dev/null || echo "0")
        total_q_count=$(echo "$RMQ_QUEUES_DATA" | jq 'length' 2>/dev/null || echo "0")
        if [ "${total_q_count:-0}" -gt 0 ] 2>/dev/null && [ "${all_consumerless:-0}" -gt 0 ] 2>/dev/null; then
            consumerless_pct=$(( all_consumerless * 100 / total_q_count ))
            if [ "$consumerless_pct" -gt 75 ]; then consumer_score=85
            elif [ "$consumerless_pct" -gt 50 ]; then consumer_score=90
            elif [ "$consumerless_pct" -gt 25 ]; then consumer_score=95
            fi
        fi
    fi

    # --- C. Queue Growth Rate (20%) ---
    # Net growth = publish rate - deliver rate (from overview)
    local publish_rate deliver_rate net_growth
    publish_rate=$(echo "$RMQ_RAW_DATA" | jq '.message_stats.publish_details.rate // 0' 2>/dev/null || echo "0")
    deliver_rate=$(echo "$RMQ_RAW_DATA" | jq '.message_stats.deliver_get_details.rate // 0' 2>/dev/null || echo "0")
    net_growth=$(echo "$publish_rate - $deliver_rate" | bc 2>/dev/null || echo "0")
    # bc may return negative; treat <=0 as perfect
    local net_growth_int
    net_growth_int=$(printf "%.0f" "$net_growth" 2>/dev/null || echo "0")

    local growth_score=100
    if [ "$net_growth_int" -le 0 ] 2>/dev/null; then growth_score=100
    elif [ "$net_growth_int" -gt 1000 ]; then growth_score=25
    elif [ "$net_growth_int" -gt 100 ]; then growth_score=50
    elif [ "$net_growth_int" -gt 10 ]; then growth_score=70
    elif [ "$net_growth_int" -gt 0 ]; then growth_score=85
    fi

    # --- D. Unacknowledged Messages (15%) ---
    local total_msgs msgs_unack unack_pct
    total_msgs=$(json_val "$RMQ_RAW_DATA" "queue_totals.messages" "0")
    msgs_unack=$(json_val "$RMQ_RAW_DATA" "queue_totals.messages_unacknowledged" "0")
    total_msgs=$(printf "%.0f" "$total_msgs" 2>/dev/null || echo "0")
    msgs_unack=$(printf "%.0f" "$msgs_unack" 2>/dev/null || echo "0")

    if [ "$total_msgs" -gt 0 ] 2>/dev/null; then
        unack_pct=$(_bc_int "$msgs_unack * 100 / $total_msgs")
    else
        unack_pct=0
    fi

    local unack_score=100
    if [ "$unack_pct" -gt 50 ]; then unack_score=25
    elif [ "$unack_pct" -gt 30 ]; then unack_score=50
    elif [ "$unack_pct" -gt 15 ]; then unack_score=70
    elif [ "$unack_pct" -gt 5 ]; then unack_score=85
    fi

    # --- E. Queue Memory Usage (10%) ---
    # Max single queue memory in MB
    local max_queue_mem_bytes max_queue_mem_mb
    max_queue_mem_bytes=$(echo "$RMQ_QUEUES_DATA" | jq '[.[].memory // 0] | max // 0' 2>/dev/null || echo "0")
    max_queue_mem_mb=$(_bc_int "$max_queue_mem_bytes / 1048576")

    local qmem_score=100
    if [ "$max_queue_mem_mb" -gt 5120 ]; then qmem_score=25
    elif [ "$max_queue_mem_mb" -gt 1024 ]; then qmem_score=50
    elif [ "$max_queue_mem_mb" -gt 512 ]; then qmem_score=70
    elif [ "$max_queue_mem_mb" -gt 100 ]; then qmem_score=85
    fi

    # --- Final Queue Health Score ---
    local score
    score=$(_bc_int "($depth_score * 30 + $consumer_score * 25 + $growth_score * 20 + $unack_score * 15 + $qmem_score * 10) / 100")
    echo "$(_clamp "$score")"
}

# =============================================================================
# 2. MESSAGE FLOW & THROUGHPUT (Weight: 20%)
# =============================================================================
# Formula from doc section 4.2.3:
#   Flow = PublishRate*0.30 + DeliverAck*0.30 + Redelivery*0.20
#          + ReturnUnroutable*0.10 + BindingEfficiency*0.10
# =============================================================================
_rmq_score_flow() {
    # --- A. Publish Rate (30%) ---
    # Without a baseline we check: is there activity? Stable = good.
    local publish_rate deliver_rate ack_rate redeliver_rate return_rate
    publish_rate=$(echo "$RMQ_RAW_DATA" | jq '.message_stats.publish_details.rate // 0' 2>/dev/null || echo "0")
    deliver_rate=$(echo "$RMQ_RAW_DATA" | jq '.message_stats.deliver_get_details.rate // 0' 2>/dev/null || echo "0")
    ack_rate=$(echo "$RMQ_RAW_DATA" | jq '.message_stats.ack_details.rate // 0' 2>/dev/null || echo "0")
    redeliver_rate=$(echo "$RMQ_RAW_DATA" | jq '.message_stats.redeliver_details.rate // 0' 2>/dev/null || echo "0")
    return_rate=$(echo "$RMQ_RAW_DATA" | jq '.message_stats.return_unroutable_details.rate // 0' 2>/dev/null || echo "0")

    local total_delivered total_acked total_redelivered
    total_delivered=$(echo "$RMQ_RAW_DATA" | jq '.message_stats.deliver_get // 0' 2>/dev/null || echo "0")
    total_acked=$(echo "$RMQ_RAW_DATA" | jq '.message_stats.ack // 0' 2>/dev/null || echo "0")
    total_redelivered=$(echo "$RMQ_RAW_DATA" | jq '.message_stats.redeliver // 0' 2>/dev/null || echo "0")

    local publish_int deliver_int
    publish_int=$(printf "%.0f" "$publish_rate" 2>/dev/null || echo "0")
    deliver_int=$(printf "%.0f" "$deliver_rate" 2>/dev/null || echo "0")

    # If no message activity at all, idle broker is fine
    if [ "$publish_int" -eq 0 ] && [ "$deliver_int" -eq 0 ] 2>/dev/null; then
        echo 80
        return
    fi

    # Publish rate score — presence of activity is good; we score 85 baseline
    # (we cannot determine variance without historical data)
    local publish_score=85

    # --- B. Deliver/Acknowledge Rate (30%) ---
    local ack_ratio_pct=100
    total_delivered=$(printf "%.0f" "$total_delivered" 2>/dev/null || echo "0")
    total_acked=$(printf "%.0f" "$total_acked" 2>/dev/null || echo "0")
    if [ "$total_delivered" -gt 0 ] 2>/dev/null; then
        ack_ratio_pct=$(_bc_int "$total_acked * 100 / $total_delivered")
    fi

    local deliver_ack_score=100
    if [ "$ack_ratio_pct" -lt 50 ]; then deliver_ack_score=25
    elif [ "$ack_ratio_pct" -lt 75 ]; then deliver_ack_score=50
    elif [ "$ack_ratio_pct" -lt 90 ]; then deliver_ack_score=70
    elif [ "$ack_ratio_pct" -lt 98 ]; then deliver_ack_score=85
    fi

    # --- C. Message Redelivery (20%) ---
    local redeliver_pct=0
    total_redelivered=$(printf "%.0f" "$total_redelivered" 2>/dev/null || echo "0")
    if [ "$total_delivered" -gt 0 ] 2>/dev/null; then
        redeliver_pct=$(_bc_int "$total_redelivered * 100 / $total_delivered")
    fi

    local redeliver_score=100
    if [ "$redeliver_pct" -gt 30 ]; then redeliver_score=25
    elif [ "$redeliver_pct" -gt 15 ]; then redeliver_score=50
    elif [ "$redeliver_pct" -gt 5 ]; then redeliver_score=70
    elif [ "$redeliver_pct" -gt 1 ]; then redeliver_score=85
    fi

    # --- D. Return / Unroutable Messages (10%) ---
    local return_int
    return_int=$(printf "%.0f" "$return_rate" 2>/dev/null || echo "0")

    local return_score=100
    if [ "$return_int" -gt 100 ]; then return_score=20
    elif [ "$return_int" -gt 10 ]; then return_score=40
    elif [ "$return_int" -gt 1 ]; then return_score=60
    elif [ "$return_int" -gt 0 ]; then return_score=80
    fi

    # --- E. Exchange Binding Efficiency (10%) ---
    # Count custom exchanges (non-default, non-amq.*) without bindings
    local total_custom_exchanges exchanges_with_bindings unbound_exchanges
    total_custom_exchanges=$(echo "$RMQ_EXCHANGES_DATA" | jq '[.[] | select(.name != "" and (.name | startswith("amq.") | not))] | length' 2>/dev/null || echo "0")
    exchanges_with_bindings=$(echo "$RMQ_BINDINGS_DATA" | jq '[.[].source | select(. != "")] | unique | length' 2>/dev/null || echo "0")

    if [ "$total_custom_exchanges" -gt 0 ] 2>/dev/null; then
        unbound_exchanges=$(( total_custom_exchanges - exchanges_with_bindings ))
        if [ "$unbound_exchanges" -lt 0 ]; then unbound_exchanges=0; fi
    else
        unbound_exchanges=0
    fi

    local binding_score=100
    if [ "$unbound_exchanges" -gt 10 ]; then binding_score=20
    elif [ "$unbound_exchanges" -gt 5 ]; then binding_score=40
    elif [ "$unbound_exchanges" -gt 2 ]; then binding_score=60
    elif [ "$unbound_exchanges" -gt 0 ]; then binding_score=80
    fi

    # --- Final Message Flow Score ---
    local score
    score=$(_bc_int "($publish_score * 30 + $deliver_ack_score * 30 + $redeliver_score * 20 + $return_score * 10 + $binding_score * 10) / 100")
    echo "$(_clamp "$score")"
}

# =============================================================================
# 3. NODE RESOURCES (Weight: 15%)
# =============================================================================
# Formula from doc section 4.3.3:
#   Resources = Memory*0.30 + DiskFree*0.25 + FD*0.20 + ErlangProc*0.15
#               + CPU*0.10
# CPU not available via Management API; we give 80 (assumed OK).
# =============================================================================
_rmq_score_resources() {
    local node_count
    node_count=$(echo "$RMQ_NODES_DATA" | jq 'length' 2>/dev/null || echo "0")
    if [ "$node_count" -eq 0 ] 2>/dev/null; then
        echo 50
        return
    fi

    # --- A. Memory (30%) ---
    # Worst-case across all nodes: highest mem_used/mem_limit percentage
    local has_mem_alarm worst_mem_pct
    has_mem_alarm=$(echo "$RMQ_NODES_DATA" | jq '[.[] | select(.mem_alarm == true)] | length' 2>/dev/null || echo "0")
    worst_mem_pct=$(echo "$RMQ_NODES_DATA" | jq '[.[] | select(.running == true) | ((.mem_used // 0) * 100 / ((.mem_limit // 1) | if . == 0 then 1 else . end))] | max // 0' 2>/dev/null || echo "0")
    worst_mem_pct=$(printf "%.0f" "$worst_mem_pct" 2>/dev/null || echo "0")

    local mem_score=100
    if [ "$has_mem_alarm" -gt 0 ] 2>/dev/null; then
        mem_score=25
    elif [ "$worst_mem_pct" -gt 95 ]; then mem_score=25
    elif [ "$worst_mem_pct" -gt 80 ]; then mem_score=50
    elif [ "$worst_mem_pct" -gt 65 ]; then mem_score=70
    elif [ "$worst_mem_pct" -gt 50 ]; then mem_score=85
    fi

    # --- B. Disk Free (25%) ---
    # Ratio: disk_free / disk_free_limit — higher is better
    local has_disk_alarm worst_disk_ratio
    has_disk_alarm=$(echo "$RMQ_NODES_DATA" | jq '[.[] | select(.disk_free_alarm == true)] | length' 2>/dev/null || echo "0")
    worst_disk_ratio=$(echo "$RMQ_NODES_DATA" | jq '[.[] | select(.running == true) | ((.disk_free // 0) / ((.disk_free_limit // 1) | if . == 0 then 1 else . end))] | min // 999' 2>/dev/null || echo "999")
    worst_disk_ratio=$(printf "%.0f" "$worst_disk_ratio" 2>/dev/null || echo "999")

    local disk_score=100
    if [ "$has_disk_alarm" -gt 0 ] 2>/dev/null; then
        disk_score=25
    elif [ "$worst_disk_ratio" -lt 1 ]; then disk_score=25
    elif [ "$worst_disk_ratio" -lt 2 ]; then disk_score=50
    elif [ "$worst_disk_ratio" -lt 5 ]; then disk_score=70
    elif [ "$worst_disk_ratio" -lt 10 ]; then disk_score=85
    fi

    # --- C. File Descriptors (20%) ---
    local worst_fd_pct
    worst_fd_pct=$(echo "$RMQ_NODES_DATA" | jq '[.[] | select(.running == true) | ((.fd_used // 0) * 100 / ((.fd_total // 1) | if . == 0 then 1 else . end))] | max // 0' 2>/dev/null || echo "0")
    worst_fd_pct=$(printf "%.0f" "$worst_fd_pct" 2>/dev/null || echo "0")

    local fd_score=100
    if [ "$worst_fd_pct" -gt 90 ]; then fd_score=25
    elif [ "$worst_fd_pct" -gt 80 ]; then fd_score=50
    elif [ "$worst_fd_pct" -gt 65 ]; then fd_score=70
    elif [ "$worst_fd_pct" -gt 50 ]; then fd_score=85
    fi

    # --- D. Erlang Processes (15%) ---
    local worst_proc_pct
    worst_proc_pct=$(echo "$RMQ_NODES_DATA" | jq '[.[] | select(.running == true) | ((.proc_used // 0) * 100 / ((.proc_total // 1) | if . == 0 then 1 else . end))] | max // 0' 2>/dev/null || echo "0")
    worst_proc_pct=$(printf "%.0f" "$worst_proc_pct" 2>/dev/null || echo "0")

    local proc_score=100
    if [ "$worst_proc_pct" -gt 90 ]; then proc_score=25
    elif [ "$worst_proc_pct" -gt 75 ]; then proc_score=50
    elif [ "$worst_proc_pct" -gt 60 ]; then proc_score=70
    elif [ "$worst_proc_pct" -gt 40 ]; then proc_score=85
    fi

    # --- E. CPU (10%) — not available via Management API, assume OK ---
    local cpu_score=80

    # --- Final Node Resources Score ---
    local score
    score=$(_bc_int "($mem_score * 30 + $disk_score * 25 + $fd_score * 20 + $proc_score * 15 + $cpu_score * 10) / 100")
    echo "$(_clamp "$score")"
}

# =============================================================================
# 4. CLUSTER HEALTH (Weight: 15%)
# =============================================================================
# Formula from doc section 4.4.3:
#   Cluster = NodeAvailability*0.40 + MirrorSync*0.30 + Partition*0.20
#             + LinkHealth*0.10
# =============================================================================
_rmq_score_cluster() {
    local node_count running_nodes
    node_count=$(echo "$RMQ_NODES_DATA" | jq 'length' 2>/dev/null || echo "0")
    running_nodes=$(echo "$RMQ_NODES_DATA" | jq '[.[] | select(.running == true)] | length' 2>/dev/null || echo "0")

    # Single-node deployment
    if [ "$node_count" -le 1 ] 2>/dev/null; then
        echo 50
        return
    fi

    # --- A. Node Availability (40%) ---
    local avail_pct=100
    if [ "$node_count" -gt 0 ] 2>/dev/null; then
        avail_pct=$(_bc_int "$running_nodes * 100 / $node_count")
    fi

    local avail_score=100
    if [ "$avail_pct" -lt 40 ]; then avail_score=10
    elif [ "$avail_pct" -lt 60 ]; then avail_score=30
    elif [ "$avail_pct" -lt 80 ]; then avail_score=50
    elif [ "$avail_pct" -lt 100 ]; then avail_score=70
    fi

    # --- B. Queue Mirror/Quorum Sync (30%) ---
    # Count quorum queues with all members online, and mirrored queues fully synced
    local total_ha_queues=0 synced_queues=0

    # Quorum queues: members vs online
    local quorum_total quorum_synced
    quorum_total=$(echo "$RMQ_QUEUES_DATA" | jq '[.[] | select(.type == "quorum")] | length' 2>/dev/null || echo "0")
    quorum_synced=$(echo "$RMQ_QUEUES_DATA" | jq '[.[] | select(.type == "quorum") | select((.members // [] | length) == (.online // [] | length))] | length' 2>/dev/null || echo "0")

    # Classic mirrored queues: slave_nodes vs synchronised_slave_nodes
    local mirror_total mirror_synced
    mirror_total=$(echo "$RMQ_QUEUES_DATA" | jq '[.[] | select(.slave_nodes != null and (.slave_nodes | length) > 0)] | length' 2>/dev/null || echo "0")
    mirror_synced=$(echo "$RMQ_QUEUES_DATA" | jq '[.[] | select(.slave_nodes != null and (.slave_nodes | length) > 0) | select((.slave_nodes | length) == (.synchronised_slave_nodes // [] | length))] | length' 2>/dev/null || echo "0")

    total_ha_queues=$(( quorum_total + mirror_total ))
    synced_queues=$(( quorum_synced + mirror_synced ))

    local sync_score=100
    if [ "$total_ha_queues" -gt 0 ] 2>/dev/null; then
        local sync_pct
        sync_pct=$(_bc_int "$synced_queues * 100 / $total_ha_queues")
        if [ "$sync_pct" -lt 50 ]; then sync_score=25
        elif [ "$sync_pct" -lt 75 ]; then sync_score=50
        elif [ "$sync_pct" -lt 90 ]; then sync_score=70
        elif [ "$sync_pct" -lt 100 ]; then sync_score=85
        fi
    fi
    # If no HA queues in a cluster, that is itself a concern
    if [ "$total_ha_queues" -eq 0 ] 2>/dev/null; then sync_score=60; fi

    # --- C. Network Partitions (20%) ---
    local partition_nodes
    partition_nodes=$(echo "$RMQ_NODES_DATA" | jq '[.[] | select(.partitions != null and (.partitions | length) > 0)] | length' 2>/dev/null || echo "0")

    local partition_score=100
    if [ "$partition_nodes" -gt 1 ] 2>/dev/null; then partition_score=10
    elif [ "$partition_nodes" -gt 0 ] 2>/dev/null; then partition_score=30
    fi

    # --- D. Cluster Link Health (10%) ---
    # Presence of cluster_links entries indicates connectivity; absence = concern
    local links_present
    links_present=$(echo "$RMQ_NODES_DATA" | jq '[.[] | select(.running == true) | (.cluster_links // [] | length)] | add // 0' 2>/dev/null || echo "0")

    local link_score=80  # default: assume OK
    if [ "$running_nodes" -gt 1 ] && [ "$links_present" -eq 0 ] 2>/dev/null; then
        link_score=40  # cluster but no link info visible
    fi

    # --- Final Cluster Health Score ---
    local score
    score=$(_bc_int "($avail_score * 40 + $sync_score * 30 + $partition_score * 20 + $link_score * 10) / 100")
    echo "$(_clamp "$score")"
}

# =============================================================================
# 5. CONNECTION & CHANNEL HEALTH (Weight: 10%)
# =============================================================================
# Formula from doc section 4.5.3:
#   Connections = ConnUtilization*0.40 + ChannelUtilization*0.30
#                 + ConnChurn*0.20 + BlockedConns*0.10
# =============================================================================
_rmq_score_connections() {
    # --- A. Connection/Socket Utilization (40%) ---
    # Worst-case sockets_used/sockets_total across nodes
    local worst_socket_pct
    worst_socket_pct=$(echo "$RMQ_NODES_DATA" | jq '[.[] | select(.running == true) | ((.sockets_used // 0) * 100 / ((.sockets_total // 1) | if . == 0 then 1 else . end))] | max // 0' 2>/dev/null || echo "0")
    worst_socket_pct=$(printf "%.0f" "$worst_socket_pct" 2>/dev/null || echo "0")

    local conn_util_score=100
    if [ "$worst_socket_pct" -gt 90 ]; then conn_util_score=25
    elif [ "$worst_socket_pct" -gt 80 ]; then conn_util_score=50
    elif [ "$worst_socket_pct" -gt 65 ]; then conn_util_score=70
    elif [ "$worst_socket_pct" -gt 50 ]; then conn_util_score=85
    fi

    # --- B. Channel Utilization (30%) ---
    # Avg channels per connection
    local conn_count channel_count ch_per_conn
    conn_count=$(json_val "$RMQ_RAW_DATA" "object_totals.connections" "0")
    channel_count=$(json_val "$RMQ_RAW_DATA" "object_totals.channels" "0")
    conn_count=$(printf "%.0f" "$conn_count" 2>/dev/null || echo "0")
    channel_count=$(printf "%.0f" "$channel_count" 2>/dev/null || echo "0")

    if [ "$conn_count" -gt 0 ] 2>/dev/null; then
        ch_per_conn=$(_bc_int "$channel_count / $conn_count")
    else
        ch_per_conn=0
    fi

    local channel_score=100
    if [ "$ch_per_conn" -gt 50 ]; then channel_score=25
    elif [ "$ch_per_conn" -gt 20 ]; then channel_score=50
    elif [ "$ch_per_conn" -gt 10 ]; then channel_score=70
    elif [ "$ch_per_conn" -gt 5 ]; then channel_score=85
    fi

    # --- C. Connection Churn (20%) ---
    local churn_created churn_closed churn_total
    churn_created=$(echo "$RMQ_RAW_DATA" | jq '.churn_rates.connection_created_details.rate // 0' 2>/dev/null || echo "0")
    churn_closed=$(echo "$RMQ_RAW_DATA" | jq '.churn_rates.connection_closed_details.rate // 0' 2>/dev/null || echo "0")
    churn_created=$(printf "%.0f" "$churn_created" 2>/dev/null || echo "0")
    churn_closed=$(printf "%.0f" "$churn_closed" 2>/dev/null || echo "0")
    churn_total=$(( churn_created + churn_closed ))

    local churn_score=100
    if [ "$churn_total" -gt 50 ]; then churn_score=25
    elif [ "$churn_total" -gt 20 ]; then churn_score=50
    elif [ "$churn_total" -gt 5 ]; then churn_score=70
    elif [ "$churn_total" -gt 1 ]; then churn_score=85
    fi

    # --- D. Blocked Connections (10%) ---
    local blocked_count
    blocked_count=$(echo "$RMQ_CONNECTIONS_DATA" | jq '[.[] | select(.state == "blocked" or .state == "blocking")] | length' 2>/dev/null || echo "0")

    local blocked_score=100
    if [ "$blocked_count" -gt 50 ]; then blocked_score=0
    elif [ "$blocked_count" -gt 20 ]; then blocked_score=20
    elif [ "$blocked_count" -gt 5 ]; then blocked_score=40
    elif [ "$blocked_count" -gt 0 ]; then blocked_score=60
    fi

    # --- Final Connection & Channel Score ---
    local score
    score=$(_bc_int "($conn_util_score * 40 + $channel_score * 30 + $churn_score * 20 + $blocked_score * 10) / 100")
    echo "$(_clamp "$score")"
}

# =============================================================================
# 6. SECURITY (Weight: 10%)
# =============================================================================
# Formula from doc section 4.6.3:
#   Security = TLS*0.35 + Authentication*0.35 + PermissionVhost*0.30
# =============================================================================
_rmq_score_security() {
    # --- A. TLS/SSL Configuration (35%) ---
    # Check listeners for ssl/amqps on port 5671
    local total_listeners ssl_listeners
    total_listeners=$(echo "$RMQ_RAW_DATA" | jq '[.listeners // [] | .[]] | length' 2>/dev/null || echo "0")
    ssl_listeners=$(echo "$RMQ_RAW_DATA" | jq '[.listeners // [] | .[] | select(.protocol == "amqp/ssl" or .port == 5671)] | length' 2>/dev/null || echo "0")

    local tls_score=20  # no TLS by default
    if [ "$ssl_listeners" -gt 0 ] 2>/dev/null; then
        if [ "$total_listeners" -gt 0 ] 2>/dev/null; then
            # Both TLS and non-TLS listeners present
            local non_ssl_amqp
            non_ssl_amqp=$(echo "$RMQ_RAW_DATA" | jq '[.listeners // [] | .[] | select(.protocol == "amqp" and .port != 5671)] | length' 2>/dev/null || echo "0")
            if [ "$non_ssl_amqp" -eq 0 ] 2>/dev/null; then
                tls_score=100  # Only TLS listeners for AMQP
            else
                tls_score=60   # TLS available but not enforced
            fi
        else
            tls_score=80
        fi
    fi

    # --- B. Authentication (35%) ---
    # Check for guest user connections from non-localhost
    local guest_remote_conns
    guest_remote_conns=$(echo "$RMQ_CONNECTIONS_DATA" | jq '[.[] | select(.user == "guest" and .peer_host != "127.0.0.1" and .peer_host != "::1" and .peer_host != "localhost")] | length' 2>/dev/null || echo "0")

    local guest_score=85  # Assume guest restricted to localhost by default
    if [ "$guest_remote_conns" -gt 0 ] 2>/dev/null; then
        guest_score=20  # Guest accessible remotely — serious concern
    fi

    # Count admin users (not directly available, but we can check connections)
    # Multiple distinct users is a good sign
    local distinct_users
    distinct_users=$(echo "$RMQ_CONNECTIONS_DATA" | jq '[.[].user // "unknown"] | unique | length' 2>/dev/null || echo "1")

    local admin_score=70
    if [ "$distinct_users" -gt 3 ] 2>/dev/null; then admin_score=85; fi
    if [ "$distinct_users" -le 1 ] 2>/dev/null; then admin_score=50; fi

    local auth_score
    auth_score=$(_bc_int "($guest_score * 60 + $admin_score * 40) / 100")

    # --- C. Permission & Vhost (30%) ---
    local vhost_count
    vhost_count=$(echo "$RMQ_VHOSTS_DATA" | jq 'length' 2>/dev/null || echo "1")

    local perm_score=50  # single vhost default
    if [ "$vhost_count" -gt 2 ] 2>/dev/null; then
        perm_score=80  # multiple vhosts = good isolation
    elif [ "$vhost_count" -gt 1 ] 2>/dev/null; then
        perm_score=70
    fi
    # If multiple users exist, bump score slightly
    if [ "$distinct_users" -gt 2 ] 2>/dev/null && [ "$perm_score" -lt 80 ]; then
        perm_score=$(( perm_score + 10 ))
    fi

    # --- Final Security Score ---
    local score
    score=$(_bc_int "($tls_score * 35 + $auth_score * 35 + $perm_score * 30) / 100")
    echo "$(_clamp "$score")"
}

# =============================================================================
# 7. PERSISTENCE & DURABILITY (Weight: 5%)
# =============================================================================
# Formula from doc section 4.7.3:
#   Persistence = WriteLatency*0.40 + PersistenceRatio*0.30 + Durability*0.30
# =============================================================================
_rmq_score_persistence() {
    # --- A. Disk Write Latency (40%) ---
    local worst_io_write
    worst_io_write=$(echo "$RMQ_NODES_DATA" | jq '[.[].io_write_avg_time // 0] | max // 0' 2>/dev/null || echo "0")
    worst_io_write=$(printf "%.0f" "$worst_io_write" 2>/dev/null || echo "0")

    local write_score=100
    if [ "$worst_io_write" -gt 50 ]; then write_score=25
    elif [ "$worst_io_write" -gt 20 ]; then write_score=50
    elif [ "$worst_io_write" -gt 5 ]; then write_score=70
    elif [ "$worst_io_write" -gt 1 ]; then write_score=85
    fi

    # --- B. Persistence Ratio (30%) ---
    # Durable queues / total queues with messages
    local total_queues_with_msgs durable_queues durable_pct
    total_queues_with_msgs=$(echo "$RMQ_QUEUES_DATA" | jq '[.[] | select((.messages // 0) > 0)] | length' 2>/dev/null || echo "0")
    durable_queues=$(echo "$RMQ_QUEUES_DATA" | jq '[.[] | select(.durable == true and (.messages // 0) > 0)] | length' 2>/dev/null || echo "0")

    local persist_score=100
    if [ "$total_queues_with_msgs" -gt 0 ] 2>/dev/null; then
        durable_pct=$(_bc_int "$durable_queues * 100 / $total_queues_with_msgs")
        if [ "$durable_pct" -lt 40 ]; then persist_score=25
        elif [ "$durable_pct" -lt 60 ]; then persist_score=50
        elif [ "$durable_pct" -lt 80 ]; then persist_score=70
        elif [ "$durable_pct" -lt 95 ]; then persist_score=85
        fi
    fi

    # --- C. Queue Durability / Type (30%) ---
    # Quorum queues score highest; durable classic is OK; non-durable is bad
    local total_queues quorum_queues all_durable non_durable_count
    total_queues=$(echo "$RMQ_QUEUES_DATA" | jq 'length' 2>/dev/null || echo "0")
    quorum_queues=$(echo "$RMQ_QUEUES_DATA" | jq '[.[] | select(.type == "quorum")] | length' 2>/dev/null || echo "0")
    all_durable=$(echo "$RMQ_QUEUES_DATA" | jq '[.[] | select(.durable == true)] | length' 2>/dev/null || echo "0")

    local durability_score=75  # default baseline
    if [ "$total_queues" -gt 0 ] 2>/dev/null; then
        non_durable_count=$(( total_queues - all_durable ))
        if [ "$quorum_queues" -gt 0 ] && [ "$non_durable_count" -eq 0 ]; then
            durability_score=100  # All durable + quorum queues present
        elif [ "$non_durable_count" -eq 0 ]; then
            durability_score=85   # All durable, classic
        elif [ "$non_durable_count" -lt "$total_queues" ]; then
            durability_score=50   # Mixed
        else
            durability_score=25   # All non-durable
        fi
    fi

    # --- Final Persistence Score ---
    local score
    score=$(_bc_int "($write_score * 40 + $persist_score * 30 + $durability_score * 30) / 100")
    echo "$(_clamp "$score")"
}

# =============================================================================
# 8. CONFIGURATION BEST PRACTICES (Weight: 5%)
# =============================================================================
# Compliance-based: 10 checks, 10 points each → 0-100
# =============================================================================
_rmq_score_config() {
    local config_score=0

    # 1. Memory watermark configured — if mem_limit is set, we score it
    local mem_limit
    mem_limit=$(echo "$RMQ_NODES_DATA" | jq '.[0].mem_limit // 0' 2>/dev/null || echo "0")
    if [ "$mem_limit" -gt 0 ] 2>/dev/null; then
        config_score=$(( config_score + 10 ))
    fi

    # 2. Disk free limit configured
    local disk_limit
    disk_limit=$(echo "$RMQ_NODES_DATA" | jq '.[0].disk_free_limit // 0' 2>/dev/null || echo "0")
    if [ "$disk_limit" -gt 0 ] 2>/dev/null; then
        config_score=$(( config_score + 10 ))
    fi

    # 3. Cluster partition handling — inferred from cluster size > 1
    local node_count
    node_count=$(echo "$RMQ_NODES_DATA" | jq 'length' 2>/dev/null || echo "0")
    if [ "$node_count" -gt 1 ] 2>/dev/null; then
        config_score=$(( config_score + 10 ))  # Clustering configured
    fi

    # 4. Queue/Message TTL — check if any queue has x-message-ttl argument
    local ttl_queues
    ttl_queues=$(echo "$RMQ_QUEUES_DATA" | jq '[.[] | select(.arguments["x-message-ttl"] != null)] | length' 2>/dev/null || echo "0")
    if [ "$ttl_queues" -gt 0 ] 2>/dev/null; then
        config_score=$(( config_score + 10 ))
    fi

    # 5. Consumer prefetch — check channels for non-zero prefetch_count
    local prefetch_channels total_consumer_channels
    total_consumer_channels=$(echo "$RMQ_CHANNELS_DATA" | jq '[.[] | select(.consumer_count > 0)] | length' 2>/dev/null || echo "0")
    prefetch_channels=$(echo "$RMQ_CHANNELS_DATA" | jq '[.[] | select(.consumer_count > 0 and .prefetch_count > 0)] | length' 2>/dev/null || echo "0")
    if [ "$total_consumer_channels" -gt 0 ] 2>/dev/null; then
        if [ "$prefetch_channels" -eq "$total_consumer_channels" ] 2>/dev/null; then
            config_score=$(( config_score + 10 ))
        fi
    else
        config_score=$(( config_score + 10 ))  # No consumers = N/A = pass
    fi

    # 6. Heartbeat — present if connections exist (default enabled)
    if [ "$(echo "$RMQ_CONNECTIONS_DATA" | jq 'length' 2>/dev/null || echo "0")" -gt 0 ] 2>/dev/null; then
        config_score=$(( config_score + 10 ))
    else
        config_score=$(( config_score + 5 ))  # Idle, partial credit
    fi

    # 7. Management plugin enabled — if we got RMQ_RAW_DATA, management is on
    if [ -n "$RMQ_RAW_DATA" ]; then
        config_score=$(( config_score + 10 ))
    fi

    # 8. Log / monitoring — inferred from rates_mode presence
    local rates_mode
    rates_mode=$(echo "$RMQ_RAW_DATA" | jq -r '.rates_mode // "none"' 2>/dev/null || echo "none")
    if [ "$rates_mode" != "none" ] && [ "$rates_mode" != "null" ] && [ -n "$rates_mode" ]; then
        config_score=$(( config_score + 10 ))
    fi

    # 9. Quorum queues or lazy queues for large queues
    local quorum_count
    quorum_count=$(echo "$RMQ_QUEUES_DATA" | jq '[.[] | select(.type == "quorum")] | length' 2>/dev/null || echo "0")
    if [ "$quorum_count" -gt 0 ] 2>/dev/null; then
        config_score=$(( config_score + 10 ))
    fi

    # 10. Dead letter exchange configured
    local dlx_queues
    dlx_queues=$(echo "$RMQ_QUEUES_DATA" | jq '[.[] | select(.arguments["x-dead-letter-exchange"] != null)] | length' 2>/dev/null || echo "0")
    if [ "$dlx_queues" -gt 0 ] 2>/dev/null; then
        config_score=$(( config_score + 10 ))
    fi

    echo "$(_clamp "$config_score")"
}

# =============================================================================
# ORCHESTRATOR — calculate_rabbitmq_score
# =============================================================================
calculate_rabbitmq_score() {
    # Early exit if not connected or no data
    if [ "$EXTERNAL_RABBITMQ_STATUS" != "connected" ] || [ -z "$RMQ_RAW_DATA" ]; then
        RMQ_SCORE=0
        RMQ_RATING_TEXT="N/A"
        RMQ_RATING_EMOJI=""
        return 0
    fi

    if [ "$JQ_AVAILABLE" != "true" ]; then
        log_warning "jq is not available — using default RabbitMQ score of 50"
        RMQ_SCORE=50
        RMQ_RATING_TEXT=$(get_rating_text 50)
        RMQ_RATING_EMOJI=$(get_rating_emoji 50)
        return 0
    fi

    log_info "Calculating RabbitMQ scores..."

    # Run all category scorers
    RMQ_SCORE_QUEUES=$(_rmq_score_queues)
    RMQ_SCORE_FLOW=$(_rmq_score_flow)
    RMQ_SCORE_RESOURCES=$(_rmq_score_resources)
    RMQ_SCORE_CLUSTER=$(_rmq_score_cluster)
    RMQ_SCORE_CONNECTIONS=$(_rmq_score_connections)
    RMQ_SCORE_SECURITY=$(_rmq_score_security)
    RMQ_SCORE_PERSISTENCE=$(_rmq_score_persistence)
    RMQ_SCORE_CONFIG=$(_rmq_score_config)

    # Weighted overall score
    RMQ_SCORE=$(_bc_int "($RMQ_SCORE_QUEUES * $RMQ_WEIGHT_QUEUES + $RMQ_SCORE_FLOW * $RMQ_WEIGHT_THROUGHPUT + $RMQ_SCORE_RESOURCES * $RMQ_WEIGHT_RESOURCES + $RMQ_SCORE_CLUSTER * $RMQ_WEIGHT_CLUSTER + $RMQ_SCORE_CONNECTIONS * $RMQ_WEIGHT_CONNECTIONS + $RMQ_SCORE_SECURITY * $RMQ_WEIGHT_SECURITY + $RMQ_SCORE_PERSISTENCE * $RMQ_WEIGHT_PERSISTENCE + $RMQ_SCORE_CONFIG * $RMQ_WEIGHT_CONFIG) / 100")
    RMQ_SCORE=$(_clamp "$RMQ_SCORE")

    # Set per-category ratings
    RMQ_RATING_QUEUES=$(get_rating_text "$RMQ_SCORE_QUEUES")
    RMQ_EMOJI_QUEUES=$(get_rating_emoji "$RMQ_SCORE_QUEUES")

    RMQ_RATING_FLOW=$(get_rating_text "$RMQ_SCORE_FLOW")
    RMQ_EMOJI_FLOW=$(get_rating_emoji "$RMQ_SCORE_FLOW")

    RMQ_RATING_RESOURCES=$(get_rating_text "$RMQ_SCORE_RESOURCES")
    RMQ_EMOJI_RESOURCES=$(get_rating_emoji "$RMQ_SCORE_RESOURCES")

    RMQ_RATING_CLUSTER=$(get_rating_text "$RMQ_SCORE_CLUSTER")
    RMQ_EMOJI_CLUSTER=$(get_rating_emoji "$RMQ_SCORE_CLUSTER")

    RMQ_RATING_CONNECTIONS=$(get_rating_text "$RMQ_SCORE_CONNECTIONS")
    RMQ_EMOJI_CONNECTIONS=$(get_rating_emoji "$RMQ_SCORE_CONNECTIONS")

    RMQ_RATING_SECURITY=$(get_rating_text "$RMQ_SCORE_SECURITY")
    RMQ_EMOJI_SECURITY=$(get_rating_emoji "$RMQ_SCORE_SECURITY")

    RMQ_RATING_PERSISTENCE=$(get_rating_text "$RMQ_SCORE_PERSISTENCE")
    RMQ_EMOJI_PERSISTENCE=$(get_rating_emoji "$RMQ_SCORE_PERSISTENCE")

    RMQ_RATING_CONFIG=$(get_rating_text "$RMQ_SCORE_CONFIG")
    RMQ_EMOJI_CONFIG=$(get_rating_emoji "$RMQ_SCORE_CONFIG")

    # Set overall rating
    RMQ_RATING_TEXT=$(get_rating_text "$RMQ_SCORE")
    RMQ_RATING_EMOJI=$(get_rating_emoji "$RMQ_SCORE")

    log_success "RabbitMQ scoring complete — Overall: ${RMQ_SCORE}/100 (${RMQ_RATING_TEXT})"
}
