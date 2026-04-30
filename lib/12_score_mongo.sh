#!/bin/bash
# =============================================================================
# 12_score_mongo.sh - MongoDB Health Scoring (0-100 scale)
# =============================================================================
# 8 categories weighted per methodology doc:
#   Performance 20%, Replication Health 20%, Resource Utilization 15%,
#   Storage & WiredTiger 15%, Security 10%, Cluster Topology 10%,
#   Index Health 5%, Configuration 5%
#
# Compatibility: Bash 3.2+ (no associative arrays, no namerefs)
# =============================================================================
# Dependencies (sourced before this file):
#   - 01_util.sh      (json_val, log_info, log_success, get_rating_text, get_rating_emoji)
#   - 10_score_k8s.sh (_bc_int, _clamp)
# =============================================================================

# ---------------------------------------------------------------------------
# Global score variables
# ---------------------------------------------------------------------------
MONGO_SCORE=0
MONGO_SCORE_PERFORMANCE=0
MONGO_SCORE_REPLICATION=0
MONGO_SCORE_RESOURCES=0
MONGO_SCORE_STORAGE=0
MONGO_SCORE_SECURITY=0
MONGO_SCORE_CLUSTER=0
MONGO_SCORE_INDEX=0
MONGO_SCORE_CONFIG=0
MONGO_RATING_TEXT=""
MONGO_RATING_EMOJI=""

# Category weights (sum = 100)
MONGO_WEIGHT_PERFORMANCE=20
MONGO_WEIGHT_REPLICATION=20
MONGO_WEIGHT_RESOURCES=15
MONGO_WEIGHT_STORAGE=15
MONGO_WEIGHT_SECURITY=10
MONGO_WEIGHT_TOPOLOGY=10
MONGO_WEIGHT_INDEXES=5
MONGO_WEIGHT_CONFIG=5

# =============================================================================
# 1. PERFORMANCE (Weight: 20%)
# =============================================================================
# Sub-weights: Read Latency 35%, Write Latency 35%, Queue Depth 30%
# =============================================================================
_mongo_score_performance() {
    local read_lat_us read_ops write_lat_us write_ops
    read_lat_us=$(json_val "$MONGO_RAW_DATA" "read_latency_us" "0")
    read_ops=$(json_val "$MONGO_RAW_DATA" "read_ops" "0")
    write_lat_us=$(json_val "$MONGO_RAW_DATA" "write_latency_us" "0")
    write_ops=$(json_val "$MONGO_RAW_DATA" "write_ops" "0")

    # --- Read Latency Score ---
    # avg = read_latency_us / read_ops (microseconds), convert to ms by /1000
    local read_score=25
    if [ "$read_ops" -gt 0 ] 2>/dev/null; then
        local avg_read_us=$(_bc_int "$read_lat_us / $read_ops")
        local avg_read_ms=$(_bc_int "$avg_read_us / 1000")
        if [ "$avg_read_ms" -lt 1 ]; then read_score=100
        elif [ "$avg_read_ms" -lt 5 ]; then read_score=85
        elif [ "$avg_read_ms" -lt 20 ]; then read_score=70
        elif [ "$avg_read_ms" -lt 100 ]; then read_score=50
        fi
    else
        # No read ops — no penalty, assume healthy
        read_score=100
    fi

    # --- Write Latency Score ---
    local write_score=25
    if [ "$write_ops" -gt 0 ] 2>/dev/null; then
        local avg_write_us=$(_bc_int "$write_lat_us / $write_ops")
        local avg_write_ms=$(_bc_int "$avg_write_us / 1000")
        if [ "$avg_write_ms" -lt 5 ]; then write_score=100
        elif [ "$avg_write_ms" -lt 20 ]; then write_score=85
        elif [ "$avg_write_ms" -lt 50 ]; then write_score=70
        elif [ "$avg_write_ms" -lt 200 ]; then write_score=50
        fi
    else
        write_score=100
    fi

    # --- Queue Depth Score ---
    local queue_r queue_w
    queue_r=$(json_val "$MONGO_RAW_DATA" "queue_readers" "0")
    queue_w=$(json_val "$MONGO_RAW_DATA" "queue_writers" "0")
    local queue_total=$((queue_r + queue_w))
    local queue_score=100
    if [ "$queue_total" -gt 50 ] 2>/dev/null; then queue_score=25
    elif [ "$queue_total" -gt 20 ] 2>/dev/null; then queue_score=50
    elif [ "$queue_total" -gt 5 ] 2>/dev/null; then queue_score=70
    elif [ "$queue_total" -gt 0 ] 2>/dev/null; then queue_score=85
    fi

    # Weighted: read 35 + write 35 + queue 30
    local result=$(_bc_int "($read_score * 35 + $write_score * 35 + $queue_score * 30) / 100")
    result=$(_clamp "$result")
    echo "$result"
}

# =============================================================================
# 2. REPLICATION HEALTH (Weight: 20%)
# =============================================================================
# If replica set: Member Health 40%, Has Primary 20%, Replication Lag 40%
# If standalone: fixed 60
# =============================================================================
_mongo_score_replication() {
    local is_rs
    is_rs=$(json_val "$MONGO_RAW_DATA" "is_replicaset" "false")

    if [ "$is_rs" != "true" ]; then
        # Standalone penalty
        echo "60"
        return
    fi

    local member_count healthy_members has_primary max_lag
    member_count=$(json_val "$MONGO_RAW_DATA" "member_count" "0")
    healthy_members=$(json_val "$MONGO_RAW_DATA" "healthy_members" "0")
    has_primary=$(json_val "$MONGO_RAW_DATA" "has_primary" "false")
    max_lag=$(json_val "$MONGO_RAW_DATA" "max_lag_seconds" "0")
    local max_lag_int
    max_lag_int=$(printf "%.0f" "$max_lag" 2>/dev/null || echo "0")

    # --- Member Health Score ---
    local member_score=0
    if [ "$member_count" -gt 0 ] 2>/dev/null; then
        member_score=$(_bc_int "$healthy_members * 100 / $member_count")
    fi
    member_score=$(_clamp "$member_score")

    # --- Has Primary Score (critical) ---
    local primary_score=0
    if [ "$has_primary" = "true" ]; then
        primary_score=100
    fi

    # --- Replication Lag Score ---
    local lag_score=100
    if [ "$max_lag_int" -gt 300 ] 2>/dev/null; then lag_score=25
    elif [ "$max_lag_int" -gt 30 ] 2>/dev/null; then lag_score=50
    elif [ "$max_lag_int" -gt 5 ] 2>/dev/null; then lag_score=70
    elif [ "$max_lag_int" -gt 1 ] 2>/dev/null; then lag_score=85
    fi

    # Weighted: member 40 + primary 20 + lag 40
    local result=$(_bc_int "($member_score * 40 + $primary_score * 20 + $lag_score * 40) / 100")
    result=$(_clamp "$result")
    echo "$result"
}

# =============================================================================
# 3. RESOURCE UTILIZATION (Weight: 15%)
# =============================================================================
# Sub-weights: Connection Utilization 40%, Cache Utilization 35%,
#              Dirty Cache Ratio 25%
# =============================================================================
_mongo_score_resources() {
    # --- Connection Utilization ---
    local conn_current conn_available
    conn_current=$(json_val "$MONGO_RAW_DATA" "conn_current" "0")
    conn_available=$(json_val "$MONGO_RAW_DATA" "conn_available" "1")
    local conn_total=$((conn_current + conn_available))

    local conn_score=100
    if [ "$conn_total" -gt 0 ] 2>/dev/null; then
        local conn_util_pct=$(_bc_int "$conn_current * 100 / $conn_total")
        if [ "$conn_util_pct" -gt 95 ] 2>/dev/null; then conn_score=25
        elif [ "$conn_util_pct" -gt 85 ] 2>/dev/null; then conn_score=50
        elif [ "$conn_util_pct" -gt 75 ] 2>/dev/null; then conn_score=70
        elif [ "$conn_util_pct" -gt 60 ] 2>/dev/null; then conn_score=85
        fi
    fi

    # --- Cache Utilization ---
    # Moderate usage is healthy; very high is bad
    local cache_used cache_max
    cache_used=$(json_val "$MONGO_RAW_DATA" "cache_bytes_used" "0")
    cache_max=$(json_val "$MONGO_RAW_DATA" "cache_bytes_max" "1")

    local cache_score=100
    if [ "$cache_max" -gt 0 ] 2>/dev/null; then
        local cache_util_pct=$(_bc_int "$cache_used * 100 / $cache_max")
        if [ "$cache_util_pct" -gt 95 ] 2>/dev/null; then cache_score=50
        elif [ "$cache_util_pct" -gt 90 ] 2>/dev/null; then cache_score=70
        elif [ "$cache_util_pct" -gt 80 ] 2>/dev/null; then cache_score=85
        fi
    fi

    # --- Dirty Cache Ratio ---
    local cache_dirty
    cache_dirty=$(json_val "$MONGO_RAW_DATA" "cache_dirty" "0")

    local dirty_score=100
    if [ "$cache_used" -gt 0 ] 2>/dev/null; then
        local dirty_pct=$(_bc_int "$cache_dirty * 100 / $cache_used")
        if [ "$dirty_pct" -gt 40 ] 2>/dev/null; then dirty_score=25
        elif [ "$dirty_pct" -gt 20 ] 2>/dev/null; then dirty_score=50
        elif [ "$dirty_pct" -gt 10 ] 2>/dev/null; then dirty_score=70
        elif [ "$dirty_pct" -gt 5 ] 2>/dev/null; then dirty_score=85
        fi
    fi

    # Weighted: conn 40 + cache 35 + dirty 25
    local result=$(_bc_int "($conn_score * 40 + $cache_score * 35 + $dirty_score * 25) / 100")
    result=$(_clamp "$result")
    echo "$result"
}

# =============================================================================
# 4. STORAGE & WIREDTIGER (Weight: 15%)
# =============================================================================
# Sub-weights: Disk Usage 30%, Compression 20%, Cache Dirty Ratio 20%,
#              Checkpoint Duration 30%
# =============================================================================
_mongo_score_storage() {
    # --- Disk Usage ---
    local fs_total fs_used
    fs_total=$(json_val "$MONGO_RAW_DATA" "fs_total_size" "0")
    fs_used=$(json_val "$MONGO_RAW_DATA" "fs_used_size" "0")

    local disk_score=100
    if [ "$fs_total" -gt 0 ] 2>/dev/null; then
        local fs_util_pct=$(_bc_int "$fs_used * 100 / $fs_total")
        if [ "$fs_util_pct" -gt 95 ] 2>/dev/null; then disk_score=10
        elif [ "$fs_util_pct" -gt 85 ] 2>/dev/null; then disk_score=40
        elif [ "$fs_util_pct" -gt 75 ] 2>/dev/null; then disk_score=60
        elif [ "$fs_util_pct" -gt 60 ] 2>/dev/null; then disk_score=80
        fi
    fi

    # --- Compression Effectiveness ---
    local compress_pct
    compress_pct=$(json_val "$MONGO_RAW_DATA" "compression_savings_pct" "0")
    local compress_int
    compress_int=$(printf "%.0f" "$compress_pct" 2>/dev/null || echo "0")

    local compress_score=50
    if [ "$compress_int" -gt 60 ] 2>/dev/null; then compress_score=100
    elif [ "$compress_int" -gt 40 ] 2>/dev/null; then compress_score=85
    elif [ "$compress_int" -gt 20 ] 2>/dev/null; then compress_score=70
    elif [ "$compress_int" -gt 0 ] 2>/dev/null; then compress_score=50
    elif [ "$compress_int" -lt 0 ] 2>/dev/null; then compress_score=25
    fi

    # --- Cache Dirty Ratio (from WiredTiger perspective) ---
    local cache_dirty cache_used
    cache_dirty=$(json_val "$MONGO_RAW_DATA" "cache_dirty" "0")
    cache_used=$(json_val "$MONGO_RAW_DATA" "cache_bytes_used" "1")

    local wt_dirty_score=100
    if [ "$cache_used" -gt 0 ] 2>/dev/null; then
        local dirty_pct=$(_bc_int "$cache_dirty * 100 / $cache_used")
        if [ "$dirty_pct" -gt 40 ] 2>/dev/null; then wt_dirty_score=25
        elif [ "$dirty_pct" -gt 20 ] 2>/dev/null; then wt_dirty_score=50
        elif [ "$dirty_pct" -gt 10 ] 2>/dev/null; then wt_dirty_score=70
        elif [ "$dirty_pct" -gt 5 ] 2>/dev/null; then wt_dirty_score=85
        fi
    fi

    # --- Checkpoint Duration ---
    local ckpt_ms
    ckpt_ms=$(json_val "$MONGO_RAW_DATA" "checkpoint_last_duration_ms" "0")
    local ckpt_int
    ckpt_int=$(printf "%.0f" "$ckpt_ms" 2>/dev/null || echo "0")

    local ckpt_score=100
    if [ "$ckpt_int" -gt 60000 ] 2>/dev/null; then ckpt_score=25
    elif [ "$ckpt_int" -gt 30000 ] 2>/dev/null; then ckpt_score=50
    elif [ "$ckpt_int" -gt 5000 ] 2>/dev/null; then ckpt_score=70
    elif [ "$ckpt_int" -gt 1000 ] 2>/dev/null; then ckpt_score=85
    fi

    # Weighted: disk 30 + compression 20 + dirty 20 + checkpoint 30
    local result=$(_bc_int "($disk_score * 30 + $compress_score * 20 + $wt_dirty_score * 20 + $ckpt_score * 30) / 100")
    result=$(_clamp "$result")
    echo "$result"
}

# =============================================================================
# 5. SECURITY (Weight: 10%)
# =============================================================================
# Heuristic: if connected with credentials -> 75 baseline
# Auth in use (infer from credentials) -> 50 points
# Connection encryption (if available)  -> 25 points
# No credentials -> 50 baseline
# =============================================================================
_mongo_score_security() {
    local sec_score=50

    # If MONGO_RAW_DATA exists and we got here, we connected successfully.
    # Check if credentials were used (implies auth is enabled).
    if [ -n "$EXTERNAL_MONGO_USER" ] && [ -n "$EXTERNAL_MONGO_PASS" ]; then
        sec_score=75
    elif [ -n "$EXTERNAL_MONGO_USER" ] || [ -n "$EXTERNAL_MONGO_PASS" ]; then
        sec_score=65
    fi

    # Cap at 100
    if [ "$sec_score" -gt 100 ]; then sec_score=100; fi

    echo "$sec_score"
}

# =============================================================================
# 6. CLUSTER TOPOLOGY (Weight: 10%)
# =============================================================================
# If replica set: member_count scoring + node health ratio
# If standalone: 40
# =============================================================================
_mongo_score_cluster() {
    local is_rs
    is_rs=$(json_val "$MONGO_RAW_DATA" "is_replicaset" "false")

    if [ "$is_rs" != "true" ]; then
        echo "40"
        return
    fi

    local member_count healthy_members has_primary
    member_count=$(json_val "$MONGO_RAW_DATA" "member_count" "0")
    healthy_members=$(json_val "$MONGO_RAW_DATA" "healthy_members" "0")
    has_primary=$(json_val "$MONGO_RAW_DATA" "has_primary" "false")

    # --- Member Count Score ---
    local count_score=25
    local mc_int
    mc_int=$(printf "%.0f" "$member_count" 2>/dev/null || echo "0")
    if [ "$mc_int" -ge 3 ] 2>/dev/null; then count_score=100
    elif [ "$mc_int" -ge 2 ] 2>/dev/null; then count_score=70
    fi

    # --- Node Health Ratio ---
    local health_score=0
    if [ "$mc_int" -gt 0 ] 2>/dev/null; then
        health_score=$(_bc_int "$healthy_members * 100 / $mc_int")
    fi
    health_score=$(_clamp "$health_score")

    # --- Has Primary ---
    local primary_score=0
    if [ "$has_primary" = "true" ]; then
        primary_score=100
    fi

    # Weighted: count 35 + health 35 + primary 30
    local result=$(_bc_int "($count_score * 35 + $health_score * 35 + $primary_score * 30) / 100")
    result=$(_clamp "$result")
    echo "$result"
}

# =============================================================================
# 7. INDEX HEALTH (Weight: 5%)
# =============================================================================
# Checks collection index coverage from MONGO_COLLECTIONS_DATA.
# Penalizes large collections with no indexes (beyond _id).
# =============================================================================
_mongo_score_index() {
    # If no collections data, return a neutral score
    if [ -z "$MONGO_COLLECTIONS_DATA" ] || [ "$MONGO_COLLECTIONS_DATA" = "null" ] || [ "$MONGO_COLLECTIONS_DATA" = "[]" ]; then
        echo "75"
        return
    fi

    if [ "$JQ_AVAILABLE" != "true" ]; then
        echo "75"
        return
    fi

    # Count total collections and those with only 1 index (_id)
    local total_collections
    total_collections=$(echo "$MONGO_COLLECTIONS_DATA" | jq 'length' 2>/dev/null || echo "0")

    if [ "$total_collections" -le 0 ] 2>/dev/null; then
        echo "75"
        return
    fi

    # Collections with more than 1 index (beyond default _id)
    local collections_with_indexes
    collections_with_indexes=$(echo "$MONGO_COLLECTIONS_DATA" | jq '[.[] | select((.index_count // 1) > 1)] | length' 2>/dev/null || echo "0")

    # Large collections (>10000 objects) with only _id index
    local large_no_index
    large_no_index=$(echo "$MONGO_COLLECTIONS_DATA" | jq '[.[] | select((.count // 0) > 10000 and (.index_count // 1) <= 1)] | length' 2>/dev/null || echo "0")

    # Index coverage ratio
    local coverage_score
    coverage_score=$(_bc_int "$collections_with_indexes * 100 / $total_collections")
    coverage_score=$(_clamp "$coverage_score")

    # Penalty for large collections without indexes
    local penalty_score=100
    if [ "$large_no_index" -gt 10 ] 2>/dev/null; then penalty_score=25
    elif [ "$large_no_index" -gt 5 ] 2>/dev/null; then penalty_score=50
    elif [ "$large_no_index" -gt 2 ] 2>/dev/null; then penalty_score=70
    elif [ "$large_no_index" -gt 0 ] 2>/dev/null; then penalty_score=85
    fi

    # Weighted: coverage 60 + large-collection penalty 40
    local result=$(_bc_int "($coverage_score * 60 + $penalty_score * 40) / 100")
    result=$(_clamp "$result")
    echo "$result"
}

# =============================================================================
# 8. CONFIGURATION (Weight: 5%)
# =============================================================================
# WiredTiger cache configured (cache_bytes_max > 0) -> 50
# Oplog configured (oplog_max_size > 0)             -> 50
# =============================================================================
_mongo_score_config() {
    local config_score=0

    # --- WiredTiger Cache ---
    local cache_max
    cache_max=$(json_val "$MONGO_RAW_DATA" "cache_bytes_max" "0")
    local cache_max_int
    cache_max_int=$(printf "%.0f" "$cache_max" 2>/dev/null || echo "0")
    if [ "$cache_max_int" -gt 0 ] 2>/dev/null; then
        config_score=$((config_score + 50))
    fi

    # --- Oplog Configuration ---
    local oplog_max
    oplog_max=$(json_val "$MONGO_RAW_DATA" "oplog_max_size" "0")
    local oplog_max_int
    oplog_max_int=$(printf "%.0f" "$oplog_max" 2>/dev/null || echo "0")
    if [ "$oplog_max_int" -gt 0 ] 2>/dev/null; then
        config_score=$((config_score + 50))
    fi

    echo "$config_score"
}

# =============================================================================
# ORCHESTRATOR — compute weighted average and set MONGO_SCORE
# =============================================================================
calculate_mongodb_score() {
    # Early exit: not connected or no data
    if [ "$EXTERNAL_MONGO_STATUS" != "connected" ] || [ -z "$MONGO_RAW_DATA" ]; then
        MONGO_SCORE=0
        MONGO_SCORE_PERFORMANCE=0
        MONGO_SCORE_REPLICATION=0
        MONGO_SCORE_RESOURCES=0
        MONGO_SCORE_STORAGE=0
        MONGO_SCORE_SECURITY=0
        MONGO_SCORE_CLUSTER=0
        MONGO_SCORE_INDEX=0
        MONGO_SCORE_CONFIG=0
        MONGO_RATING_TEXT="Critical"
        MONGO_RATING_EMOJI="🔴"
        return 0
    fi

    log_info "Calculating MongoDB scores..."

    # Run all category scorers
    MONGO_SCORE_PERFORMANCE=$(_mongo_score_performance)
    MONGO_SCORE_REPLICATION=$(_mongo_score_replication)
    MONGO_SCORE_RESOURCES=$(_mongo_score_resources)
    MONGO_SCORE_STORAGE=$(_mongo_score_storage)
    MONGO_SCORE_SECURITY=$(_mongo_score_security)
    MONGO_SCORE_CLUSTER=$(_mongo_score_cluster)
    MONGO_SCORE_INDEX=$(_mongo_score_index)
    MONGO_SCORE_CONFIG=$(_mongo_score_config)

    # Compute overall weighted score
    MONGO_SCORE=$(_bc_int "($MONGO_SCORE_PERFORMANCE * $MONGO_WEIGHT_PERFORMANCE \
        + $MONGO_SCORE_REPLICATION * $MONGO_WEIGHT_REPLICATION \
        + $MONGO_SCORE_RESOURCES * $MONGO_WEIGHT_RESOURCES \
        + $MONGO_SCORE_STORAGE * $MONGO_WEIGHT_STORAGE \
        + $MONGO_SCORE_SECURITY * $MONGO_WEIGHT_SECURITY \
        + $MONGO_SCORE_CLUSTER * $MONGO_WEIGHT_TOPOLOGY \
        + $MONGO_SCORE_INDEX * $MONGO_WEIGHT_INDEXES \
        + $MONGO_SCORE_CONFIG * $MONGO_WEIGHT_CONFIG) / 100")
    MONGO_SCORE=$(_clamp "$MONGO_SCORE")

    # Set rating text and emoji
    MONGO_RATING_TEXT=$(get_rating_text "$MONGO_SCORE")
    MONGO_RATING_EMOJI=$(get_rating_emoji "$MONGO_SCORE")

    log_success "MongoDB scoring complete — Overall: ${MONGO_SCORE}/100 (${MONGO_RATING_TEXT})"
}
