#!/bin/bash
# =============================================================================
# 13_score_valkey.sh - Valkey/Redis Health Scoring (0-100 scale)
# =============================================================================
# 8 categories weighted per methodology doc:
#   Memory Management 20%, Performance 20%, Replication Health 15%,
#   Persistence 15%, Connection Health 10%, Cluster Health 10%,
#   Security 5%, Configuration 5%
#
# Compatibility: Bash 3.2+ (no associative arrays, no namerefs)
# =============================================================================

# --- Category weights (sum = 100) ---
VALKEY_WEIGHT_MEMORY=20
VALKEY_WEIGHT_PERFORMANCE=20
VALKEY_WEIGHT_REPLICATION=15
VALKEY_WEIGHT_PERSISTENCE=15
VALKEY_WEIGHT_CONNECTIONS=10
VALKEY_WEIGHT_CLUSTER=10
VALKEY_WEIGHT_SECURITY=5
VALKEY_WEIGHT_CONFIG=5

# --- Category scores (set by individual scorers) ---
VALKEY_SCORE_MEMORY=0
VALKEY_SCORE_PERFORMANCE=0
VALKEY_SCORE_REPLICATION=0
VALKEY_SCORE_PERSISTENCE=0
VALKEY_SCORE_CONNECTIONS=0
VALKEY_SCORE_CLUSTER=0
VALKEY_SCORE_SECURITY=0
VALKEY_SCORE_CONFIG=0
VALKEY_SCORE=0

# --- Rating outputs ---
VALKEY_RATING_TEXT=""
VALKEY_RATING_EMOJI=""

# =============================================================================
# 1. MEMORY MANAGEMENT (Weight: 20%)
# =============================================================================
# Sub-weights: Utilization 30%, Fragmentation 25%, Eviction 20%,
#              Expiration 15%, RSS Overhead 10%
# =============================================================================
_valkey_score_memory() {
    local used_memory maxmemory frag_ratio evicted_keys
    used_memory=$(redis_info_val "used_memory" "0")
    maxmemory=$(redis_info_val "maxmemory" "0")
    frag_ratio=$(redis_info_val "mem_fragmentation_ratio" "1.0")
    evicted_keys=$(redis_info_val "evicted_keys" "0")
    local used_memory_rss used_memory_peak
    used_memory_rss=$(redis_info_val "used_memory_rss" "0")
    used_memory_peak=$(redis_info_val "used_memory_peak" "0")

    # --- A. Memory Utilization (30%) ---
    local util_score=60
    if [ "$maxmemory" -gt 0 ] 2>/dev/null; then
        local util_pct
        util_pct=$(_bc_int "$used_memory * 100 / $maxmemory")
        if [ "$util_pct" -lt 60 ]; then util_score=100
        elif [ "$util_pct" -lt 75 ]; then util_score=85
        elif [ "$util_pct" -lt 85 ]; then util_score=70
        elif [ "$util_pct" -lt 95 ]; then util_score=50
        else util_score=20
        fi
    fi

    # --- B. Fragmentation Ratio (25%) ---
    # frag_ratio is a float; use bc for comparisons
    local frag_score=100
    local frag_check
    # > 5.0
    frag_check=$(echo "$frag_ratio > 5.0" | bc 2>/dev/null || echo "0")
    if [ "$frag_check" = "1" ]; then
        frag_score=10
    else
        # 3.0-5.0
        frag_check=$(echo "$frag_ratio >= 3.0" | bc 2>/dev/null || echo "0")
        if [ "$frag_check" = "1" ]; then
            frag_score=35
        else
            # 2.0-3.0
            frag_check=$(echo "$frag_ratio >= 2.0" | bc 2>/dev/null || echo "0")
            if [ "$frag_check" = "1" ]; then
                frag_score=60
            else
                # 1.5-2.0
                frag_check=$(echo "$frag_ratio >= 1.5" | bc 2>/dev/null || echo "0")
                if [ "$frag_check" = "1" ]; then
                    frag_score=80
                else
                    # 1.0-1.5 -> 100 (healthy)
                    frag_check=$(echo "$frag_ratio >= 1.0" | bc 2>/dev/null || echo "0")
                    if [ "$frag_check" = "1" ]; then
                        frag_score=100
                    else
                        # 0.8-1.0
                        frag_check=$(echo "$frag_ratio >= 0.8" | bc 2>/dev/null || echo "0")
                        if [ "$frag_check" = "1" ]; then
                            frag_score=80
                        else
                            # 0.5-0.8
                            frag_check=$(echo "$frag_ratio >= 0.5" | bc 2>/dev/null || echo "0")
                            if [ "$frag_check" = "1" ]; then
                                frag_score=60
                            else
                                # 0.3-0.5
                                frag_check=$(echo "$frag_ratio >= 0.3" | bc 2>/dev/null || echo "0")
                                if [ "$frag_check" = "1" ]; then
                                    frag_score=35
                                else
                                    frag_score=10
                                fi
                            fi
                        fi
                    fi
                fi
            fi
        fi
    fi

    # --- C. Eviction Rate (20%) ---
    # We only have cumulative evicted_keys; score by absolute count
    local evict_score=100
    if [ "$evicted_keys" -gt 1000 ] 2>/dev/null; then evict_score=10
    elif [ "$evicted_keys" -gt 100 ] 2>/dev/null; then evict_score=35
    elif [ "$evicted_keys" -gt 10 ] 2>/dev/null; then evict_score=60
    elif [ "$evicted_keys" -gt 0 ] 2>/dev/null; then evict_score=80
    fi

    # --- D. Key Expiration Health (15%) ---
    # Parse keyspace info for TTL coverage
    local expire_score=70  # default neutral
    local total_keys=0 total_expires=0
    local ks_line
    # Iterate db lines: db0:keys=N,expires=M,...
    while IFS= read -r ks_line; do
        case "$ks_line" in
            db[0-9]*)
                local k_count e_count
                k_count=$(echo "$ks_line" | sed 's/.*keys=\([0-9]*\).*/\1/' 2>/dev/null || echo "0")
                e_count=$(echo "$ks_line" | sed 's/.*expires=\([0-9]*\).*/\1/' 2>/dev/null || echo "0")
                total_keys=$((total_keys + k_count))
                total_expires=$((total_expires + e_count))
                ;;
        esac
    done <<EOF
$(echo "$VALKEY_RAW_DATA" | grep "^db[0-9]")
EOF
    if [ "$total_keys" -gt 0 ] 2>/dev/null; then
        local ttl_pct
        ttl_pct=$(_bc_int "$total_expires * 100 / $total_keys")
        if [ "$ttl_pct" -gt 70 ]; then expire_score=100
        elif [ "$ttl_pct" -gt 50 ]; then expire_score=85
        elif [ "$ttl_pct" -gt 30 ]; then expire_score=70
        elif [ "$ttl_pct" -gt 10 ]; then expire_score=50
        else expire_score=30
        fi
    fi

    # --- E. RSS Overhead (10%) ---
    local rss_score=100
    if [ "$used_memory" -gt 0 ] 2>/dev/null && [ "$used_memory_rss" -gt 0 ] 2>/dev/null; then
        local overhead_pct
        overhead_pct=$(_bc_int "($used_memory_rss - $used_memory) * 100 / $used_memory")
        if [ "$overhead_pct" -gt 200 ]; then rss_score=15
        elif [ "$overhead_pct" -gt 100 ]; then rss_score=40
        elif [ "$overhead_pct" -gt 50 ]; then rss_score=60
        elif [ "$overhead_pct" -gt 20 ]; then rss_score=80
        fi
    fi

    # --- Final Memory Score ---
    VALKEY_SCORE_MEMORY=$(_bc_int "$util_score * 30 / 100 + $frag_score * 25 / 100 + $evict_score * 20 / 100 + $expire_score * 15 / 100 + $rss_score * 10 / 100")
    VALKEY_SCORE_MEMORY=$(_clamp "$VALKEY_SCORE_MEMORY")
}

# =============================================================================
# 2. PERFORMANCE (Weight: 20%)
# =============================================================================
# Sub-weights: Hit Ratio 30%, Latency 25%, Slow Queries 20%,
#              Ops/sec 15%, Eviction Impact 10%
# =============================================================================
_valkey_score_performance() {
    local keyspace_hits keyspace_misses slowlog_len
    keyspace_hits=$(redis_info_val "keyspace_hits" "0")
    keyspace_misses=$(redis_info_val "keyspace_misses" "0")
    slowlog_len="${VALKEY_SLOWLOG_LEN:-0}"
    local total_cmds
    total_cmds=$(redis_info_val "total_commands_processed" "0")
    local evicted_keys
    evicted_keys=$(redis_info_val "evicted_keys" "0")

    # --- A. Cache Hit Ratio (30%) ---
    local hit_score=100
    local total_access=$((keyspace_hits + keyspace_misses))
    if [ "$total_access" -gt 0 ] 2>/dev/null; then
        local hit_pct
        hit_pct=$(_bc_int "$keyspace_hits * 10000 / $total_access")
        # hit_pct is in basis points (e.g. 9900 = 99.00%)
        if [ "$hit_pct" -ge 9900 ]; then hit_score=100
        elif [ "$hit_pct" -ge 9500 ]; then hit_score=85
        elif [ "$hit_pct" -ge 9000 ]; then hit_score=70
        elif [ "$hit_pct" -ge 8000 ]; then hit_score=50
        else hit_score=25
        fi
    fi

    # --- B. Command Latency (25%) ---
    # We do not have direct latency data in INFO; use a reasonable default
    # If slow log is very high, latency is likely poor
    local latency_score=85  # default: assume decent latency when connected

    # --- C. Slow Query Score (20%) ---
    local slow_score=100
    if [ "$total_cmds" -gt 0 ] 2>/dev/null && [ "$slowlog_len" -gt 0 ] 2>/dev/null; then
        # slow_ratio in basis points (1/10000)
        local slow_ratio
        slow_ratio=$(_bc_int "$slowlog_len * 1000000 / $total_cmds")
        # slow_ratio: 10 = 0.001%, 100 = 0.01%, 1000 = 0.1%, 10000 = 1%
        if [ "$slow_ratio" -lt 10 ]; then slow_score=100
        elif [ "$slow_ratio" -lt 100 ]; then slow_score=85
        elif [ "$slow_ratio" -lt 1000 ]; then slow_score=65
        elif [ "$slow_ratio" -lt 10000 ]; then slow_score=40
        else slow_score=15
        fi
    elif [ "$slowlog_len" -gt 0 ] 2>/dev/null; then
        # Fallback: score by absolute count
        if [ "$slowlog_len" -le 10 ]; then slow_score=85
        elif [ "$slowlog_len" -le 50 ]; then slow_score=70
        elif [ "$slowlog_len" -le 200 ]; then slow_score=50
        else slow_score=25
        fi
    fi

    # --- D. Ops/sec (15%) ---
    # Informational; default 85 since we cannot determine capacity baseline
    local ops_score=85

    # --- E. Eviction Impact (10%) ---
    local evict_impact_score=100
    if [ "$total_cmds" -gt 0 ] 2>/dev/null && [ "$evicted_keys" -gt 0 ] 2>/dev/null; then
        local evict_ratio
        evict_ratio=$(_bc_int "$evicted_keys * 1000000 / $total_cmds")
        # 100 = 0.01%, 1000 = 0.1%, 10000 = 1%
        if [ "$evict_ratio" -eq 0 ]; then evict_impact_score=100
        elif [ "$evict_ratio" -lt 100 ]; then evict_impact_score=85
        elif [ "$evict_ratio" -lt 1000 ]; then evict_impact_score=65
        elif [ "$evict_ratio" -lt 10000 ]; then evict_impact_score=40
        else evict_impact_score=15
        fi
    fi

    # --- Final Performance Score ---
    VALKEY_SCORE_PERFORMANCE=$(_bc_int "$hit_score * 30 / 100 + $latency_score * 25 / 100 + $slow_score * 20 / 100 + $ops_score * 15 / 100 + $evict_impact_score * 10 / 100")
    VALKEY_SCORE_PERFORMANCE=$(_clamp "$VALKEY_SCORE_PERFORMANCE")
}

# =============================================================================
# 3. REPLICATION HEALTH (Weight: 15%)
# =============================================================================
# Sub-weights: Lag 40%, Link Status 30%, Backlog 20%, Partial Resync 10%
# =============================================================================
_valkey_score_replication() {
    local role connected_slaves master_link_status master_last_io
    role=$(redis_info_val "role" "master")
    connected_slaves=$(redis_info_val "connected_slaves" "0")
    master_link_status=$(redis_info_val "master_link_status" "")
    master_last_io=$(redis_info_val "master_last_io_seconds_ago" "0")
    local master_repl_offset repl_backlog_active repl_backlog_size repl_backlog_histlen
    master_repl_offset=$(redis_info_val "master_repl_offset" "0")
    repl_backlog_active=$(redis_info_val "repl_backlog_active" "0")
    repl_backlog_size=$(redis_info_val "repl_backlog_size" "0")
    repl_backlog_histlen=$(redis_info_val "repl_backlog_histlen" "0")
    local sync_partial_ok sync_full
    sync_partial_ok=$(redis_info_val "sync_partial_ok" "0")
    sync_full=$(redis_info_val "sync_full" "0")
    local master_sync_in_progress
    master_sync_in_progress=$(redis_info_val "master_sync_in_progress" "0")

    # Detect standalone (no replication configured at all)
    local is_standalone=0
    if [ "$role" = "master" ] && [ "$connected_slaves" -eq 0 ] 2>/dev/null && [ "$repl_backlog_active" != "1" ]; then
        is_standalone=1
    fi

    if [ "$is_standalone" -eq 1 ]; then
        # Standalone penalty per methodology doc
        VALKEY_SCORE_REPLICATION=50
        return
    fi

    # --- A. Replication Lag (40%) ---
    local lag_score=100
    if [ "$role" = "master" ] && [ "$connected_slaves" -gt 0 ] 2>/dev/null; then
        # Parse slave0 line for lag and offset
        local slave0_line slave_offset slave_lag
        slave0_line=$(echo "$VALKEY_RAW_DATA" | grep "^slave0:" | tr -d '\r')
        if [ -n "$slave0_line" ]; then
            slave_offset=$(echo "$slave0_line" | sed 's/.*offset=\([0-9]*\).*/\1/' 2>/dev/null || echo "0")
            slave_lag=$(echo "$slave0_line" | sed 's/.*lag=\([0-9]*\).*/\1/' 2>/dev/null || echo "0")
            # Byte lag
            local byte_lag=0
            if [ "$master_repl_offset" -gt 0 ] 2>/dev/null && [ "$slave_offset" -gt 0 ] 2>/dev/null; then
                byte_lag=$((master_repl_offset - slave_offset))
                if [ "$byte_lag" -lt 0 ]; then byte_lag=0; fi
            fi
            local byte_lag_score=100
            if [ "$byte_lag" -gt 104857600 ]; then byte_lag_score=15       # > 100MB
            elif [ "$byte_lag" -gt 10485760 ]; then byte_lag_score=40      # > 10MB
            elif [ "$byte_lag" -gt 1048576 ]; then byte_lag_score=65       # > 1MB
            elif [ "$byte_lag" -gt 1024 ]; then byte_lag_score=85          # > 1KB
            fi
            # Time lag
            local time_lag_score=100
            if [ "$slave_lag" -gt 120 ] 2>/dev/null; then time_lag_score=10
            elif [ "$slave_lag" -gt 30 ] 2>/dev/null; then time_lag_score=35
            elif [ "$slave_lag" -gt 5 ] 2>/dev/null; then time_lag_score=60
            elif [ "$slave_lag" -gt 1 ] 2>/dev/null; then time_lag_score=80
            fi
            # Use the lower of the two
            if [ "$byte_lag_score" -lt "$time_lag_score" ]; then
                lag_score="$byte_lag_score"
            else
                lag_score="$time_lag_score"
            fi
        fi
    elif [ "$role" = "slave" ]; then
        # On replica, use master_last_io_seconds_ago as proxy for lag
        if [ "$master_last_io" -gt 120 ] 2>/dev/null; then lag_score=10
        elif [ "$master_last_io" -gt 30 ] 2>/dev/null; then lag_score=35
        elif [ "$master_last_io" -gt 5 ] 2>/dev/null; then lag_score=60
        elif [ "$master_last_io" -gt 1 ] 2>/dev/null; then lag_score=80
        fi
    fi

    # --- B. Replica Link Status (30%) ---
    local link_score=100
    if [ "$role" = "slave" ]; then
        if [ "$master_link_status" = "up" ]; then
            # Check if I/O is stale
            if [ "$master_last_io" -gt 10 ] 2>/dev/null; then
                link_score=75
            else
                link_score=100
            fi
        else
            # Link is down
            local link_down_since
            link_down_since=$(redis_info_val "master_link_down_since_seconds" "0")
            if [ "$link_down_since" -gt 60 ] 2>/dev/null; then
                link_score=25
            else
                link_score=50
            fi
        fi
    elif [ "$role" = "master" ]; then
        if [ "$connected_slaves" -gt 0 ] 2>/dev/null; then
            link_score=100
        else
            link_score=0  # Master with no connected replicas
        fi
    fi

    # --- C. Replication Backlog (20%) ---
    local backlog_score=50
    if [ "$repl_backlog_active" = "1" ]; then
        if [ "$repl_backlog_size" -gt 0 ] 2>/dev/null; then
            local backlog_util
            backlog_util=$(_bc_int "$repl_backlog_histlen * 100 / $repl_backlog_size")
            if [ "$backlog_util" -lt 50 ]; then backlog_score=100
            elif [ "$backlog_util" -lt 75 ]; then backlog_score=80
            elif [ "$backlog_util" -lt 90 ]; then backlog_score=60
            else backlog_score=35
            fi
        else
            backlog_score=50
        fi
    fi

    # --- D. Partial Resync Ratio (10%) ---
    local resync_score=100
    local total_syncs=$((sync_partial_ok + sync_full))
    if [ "$total_syncs" -gt 0 ] 2>/dev/null; then
        local partial_pct
        partial_pct=$(_bc_int "$sync_partial_ok * 100 / $total_syncs")
        if [ "$partial_pct" -ge 100 ]; then resync_score=100
        elif [ "$partial_pct" -ge 80 ]; then resync_score=80
        elif [ "$partial_pct" -ge 50 ]; then resync_score=60
        elif [ "$partial_pct" -ge 20 ]; then resync_score=40
        else resync_score=15
        fi
    fi

    # --- Final Replication Score ---
    VALKEY_SCORE_REPLICATION=$(_bc_int "$lag_score * 40 / 100 + $link_score * 30 / 100 + $backlog_score * 20 / 100 + $resync_score * 10 / 100")
    VALKEY_SCORE_REPLICATION=$(_clamp "$VALKEY_SCORE_REPLICATION")
}

# =============================================================================
# 4. PERSISTENCE (Weight: 15%)
# =============================================================================
# Sub-weights: RDB 30%, AOF 30%, Fork Time 20%, AOF Buffer 20%
# =============================================================================
_valkey_score_persistence() {
    local rdb_status aof_enabled aof_last_write aof_last_rewrite loading
    rdb_status=$(redis_info_val "rdb_last_bgsave_status" "ok")
    aof_enabled=$(redis_info_val "aof_enabled" "0")
    aof_last_write=$(redis_info_val "aof_last_write_status" "ok")
    aof_last_rewrite=$(redis_info_val "aof_last_bgrewrite_status" "ok")
    loading=$(redis_info_val "loading" "0")
    local rdb_last_save latest_fork_usec
    rdb_last_save=$(redis_info_val "rdb_last_save_time" "0")
    latest_fork_usec=$(redis_info_val "latest_fork_usec" "0")
    local aof_buffer_length aof_rewrite_in_progress rdb_changes
    aof_buffer_length=$(redis_info_val "aof_buffer_length" "0")
    aof_rewrite_in_progress=$(redis_info_val "aof_rewrite_in_progress" "0")
    rdb_changes=$(redis_info_val "rdb_changes_since_last_save" "0")

    # If currently loading a dataset, penalize heavily
    if [ "$loading" = "1" ]; then
        VALKEY_SCORE_PERSISTENCE=30
        return
    fi

    # --- A. RDB Health (30%) ---
    local rdb_score=40
    if [ "$rdb_status" = "ok" ]; then
        rdb_score=65  # OK status but unknown recency
        # Check recency if we have a save time
        if [ "$rdb_last_save" -gt 0 ] 2>/dev/null; then
            local now time_since
            now=$(date +%s 2>/dev/null || echo "0")
            if [ "$now" -gt 0 ] 2>/dev/null; then
                time_since=$((now - rdb_last_save))
                if [ "$time_since" -lt 3600 ]; then rdb_score=100       # < 1 hour
                elif [ "$time_since" -lt 21600 ]; then rdb_score=85     # < 6 hours
                elif [ "$time_since" -lt 86400 ]; then rdb_score=65     # < 24 hours
                else rdb_score=40                                        # > 24 hours
                fi
            fi
        fi
    else
        rdb_score=10  # Last bgsave failed
    fi

    # --- B. AOF Health (30%) ---
    local aof_score=50
    if [ "$aof_enabled" = "1" ]; then
        if [ "$aof_last_write" = "ok" ]; then
            aof_score=90
            # Bonus for good rewrite status
            if [ "$aof_last_rewrite" = "ok" ]; then
                aof_score=100
            fi
        else
            aof_score=25  # Last write failed
        fi
    fi
    # If both RDB failed and AOF disabled, combined penalty handled by weights

    # --- C. Fork Time (20%) ---
    local fork_score=100
    if [ "$latest_fork_usec" -gt 0 ] 2>/dev/null; then
        local fork_ms
        fork_ms=$(_bc_int "$latest_fork_usec / 1000")
        if [ "$fork_ms" -gt 1000 ]; then fork_score=15
        elif [ "$fork_ms" -gt 200 ]; then fork_score=40
        elif [ "$fork_ms" -gt 50 ]; then fork_score=65
        elif [ "$fork_ms" -gt 10 ]; then fork_score=85
        fi
    fi

    # --- D. AOF Buffer / Rewrite (20%) ---
    local aof_buf_score=100
    if [ "$aof_enabled" = "1" ]; then
        if [ "$aof_rewrite_in_progress" = "1" ]; then
            # Rewrite in progress; check buffer size
            if [ "$aof_buffer_length" -gt 10485760 ] 2>/dev/null; then
                aof_buf_score=40  # > 10MB buffer
            else
                aof_buf_score=70  # Normal rewrite
            fi
        else
            if [ "$aof_buffer_length" -gt 10485760 ] 2>/dev/null; then
                aof_buf_score=40
            elif [ "$aof_buffer_length" -gt 1048576 ] 2>/dev/null; then
                aof_buf_score=85
            fi
        fi
    fi

    # --- Final Persistence Score ---
    VALKEY_SCORE_PERSISTENCE=$(_bc_int "$rdb_score * 30 / 100 + $aof_score * 30 / 100 + $fork_score * 20 / 100 + $aof_buf_score * 20 / 100")
    VALKEY_SCORE_PERSISTENCE=$(_clamp "$VALKEY_SCORE_PERSISTENCE")
}

# =============================================================================
# 5. CONNECTION HEALTH (Weight: 10%)
# =============================================================================
# Sub-weights: Utilization 40%, Blocked 25%, Rejected 20%, Output Buffer 15%
# =============================================================================
_valkey_score_connections() {
    local connected_clients maxclients rejected_connections blocked_clients
    connected_clients=$(redis_info_val "connected_clients" "1")
    maxclients=$(redis_info_val "maxclients" "10000")
    rejected_connections=$(redis_info_val "rejected_connections" "0")
    blocked_clients=$(redis_info_val "blocked_clients" "0")
    local total_connections_received
    total_connections_received=$(redis_info_val "total_connections_received" "0")

    # --- A. Connection Utilization (40%) ---
    local util_score=100
    if [ "$maxclients" -gt 0 ] 2>/dev/null; then
        local client_pct
        client_pct=$(_bc_int "$connected_clients * 100 / $maxclients")
        if [ "$client_pct" -gt 95 ]; then util_score=10
        elif [ "$client_pct" -gt 85 ]; then util_score=35
        elif [ "$client_pct" -gt 70 ]; then util_score=60
        elif [ "$client_pct" -gt 50 ]; then util_score=80
        fi
    fi

    # --- B. Blocked Clients (25%) ---
    local blocked_score=100
    if [ "$connected_clients" -gt 0 ] 2>/dev/null && [ "$blocked_clients" -gt 0 ] 2>/dev/null; then
        local blocked_pct
        blocked_pct=$(_bc_int "$blocked_clients * 100 / $connected_clients")
        if [ "$blocked_pct" -gt 15 ]; then blocked_score=15
        elif [ "$blocked_pct" -gt 5 ]; then blocked_score=40
        elif [ "$blocked_pct" -gt 1 ]; then blocked_score=65
        elif [ "$blocked_pct" -gt 0 ]; then blocked_score=85
        fi
    fi

    # --- C. Rejected Connections (20%) ---
    local reject_score=100
    if [ "$total_connections_received" -gt 0 ] 2>/dev/null && [ "$rejected_connections" -gt 0 ] 2>/dev/null; then
        # rejected_pct in basis points (1/10000)
        local reject_bp
        reject_bp=$(_bc_int "$rejected_connections * 10000 / $total_connections_received")
        if [ "$reject_bp" -gt 100 ]; then reject_score=10        # > 1%
        elif [ "$reject_bp" -gt 10 ]; then reject_score=35       # > 0.1%
        elif [ "$reject_bp" -gt 1 ]; then reject_score=60        # > 0.01%
        else reject_score=85                                       # < 0.01%
        fi
    elif [ "$rejected_connections" -gt 0 ] 2>/dev/null; then
        # Fallback: any rejections are bad
        if [ "$rejected_connections" -gt 100 ]; then reject_score=20
        elif [ "$rejected_connections" -gt 10 ]; then reject_score=60
        else reject_score=80
        fi
    fi

    # --- D. Output Buffer (15%) ---
    # Parse CLIENT LIST for high omem values if available
    local outbuf_score=100
    if [ -n "$VALKEY_CLIENT_LIST" ]; then
        local max_omem=0
        local omem_val
        # Extract omem values
        while IFS= read -r _cl_line; do
            omem_val=$(echo "$_cl_line" | sed 's/.*omem=\([0-9]*\).*/\1/' 2>/dev/null || echo "0")
            if [ "$omem_val" -gt "$max_omem" ] 2>/dev/null; then
                max_omem="$omem_val"
            fi
        done <<EOF
$(echo "$VALKEY_CLIENT_LIST")
EOF
        if [ "$max_omem" -gt 52428800 ] 2>/dev/null; then outbuf_score=30       # > 50MB
        elif [ "$max_omem" -gt 10485760 ] 2>/dev/null; then outbuf_score=55     # > 10MB
        elif [ "$max_omem" -gt 1048576 ] 2>/dev/null; then outbuf_score=80      # > 1MB
        fi
    fi

    # --- Final Connection Health Score ---
    VALKEY_SCORE_CONNECTIONS=$(_bc_int "$util_score * 40 / 100 + $blocked_score * 25 / 100 + $reject_score * 20 / 100 + $outbuf_score * 15 / 100")
    VALKEY_SCORE_CONNECTIONS=$(_clamp "$VALKEY_SCORE_CONNECTIONS")
}

# =============================================================================
# 6. CLUSTER HEALTH (Weight: 10%)
# =============================================================================
# Sub-weights: State 40%, Slot Coverage 30%, Node Availability 20%,
#              Migration 10%
# =============================================================================
_valkey_score_cluster() {
    local cluster_enabled
    cluster_enabled=$(redis_info_val "cluster_enabled" "0")

    if [ "$cluster_enabled" != "1" ]; then
        # Standalone / Sentinel — baseline per methodology doc
        VALKEY_SCORE_CLUSTER=70
        return
    fi

    # --- A. Cluster State (40%) ---
    local cluster_state slots_pfail slots_fail
    cluster_state=$(redis_info_val "cluster_state" "ok")
    slots_pfail=$(redis_info_val "cluster_slots_pfail" "0")
    slots_fail=$(redis_info_val "cluster_slots_fail" "0")

    local state_score=100
    if [ "$cluster_state" != "ok" ]; then
        state_score=20
    elif [ "$slots_fail" -gt 0 ] 2>/dev/null; then
        state_score=20
    elif [ "$slots_pfail" -gt 0 ] 2>/dev/null; then
        state_score=70
    fi

    # --- B. Slot Coverage (30%) ---
    local slots_ok
    slots_ok=$(redis_info_val "cluster_slots_ok" "0")
    local coverage_score=0
    if [ "$slots_ok" -ge 16384 ] 2>/dev/null; then coverage_score=100
    elif [ "$slots_ok" -ge 16368 ] 2>/dev/null; then coverage_score=75   # ~99.9%
    elif [ "$slots_ok" -ge 16220 ] 2>/dev/null; then coverage_score=50   # ~99%
    elif [ "$slots_ok" -ge 15564 ] 2>/dev/null; then coverage_score=25   # ~95%
    fi

    # --- C. Node Availability (20%) ---
    local known_nodes cluster_size
    known_nodes=$(redis_info_val "cluster_known_nodes" "0")
    cluster_size=$(redis_info_val "cluster_size" "0")
    local node_score=100
    # If we cannot determine failed nodes from INFO, use state as proxy
    if [ "$cluster_state" != "ok" ]; then
        node_score=30
    elif [ "$slots_pfail" -gt 0 ] 2>/dev/null; then
        node_score=50
    fi

    # --- D. Migration Status (10%) ---
    # Without CLUSTER NODES output we default to healthy
    local migration_score=100

    # --- Final Cluster Score ---
    VALKEY_SCORE_CLUSTER=$(_bc_int "$state_score * 40 / 100 + $coverage_score * 30 / 100 + $node_score * 20 / 100 + $migration_score * 10 / 100")
    VALKEY_SCORE_CLUSTER=$(_clamp "$VALKEY_SCORE_CLUSTER")
}

# =============================================================================
# 7. SECURITY (Weight: 5%)
# =============================================================================
# Sub-weights: Authentication 40%, TLS 30%, Dangerous Commands 30%
# =============================================================================
_valkey_score_security() {
    # --- A. Authentication (40%) ---
    local auth_score=0
    if [ -n "$EXTERNAL_REDIS_PASS" ]; then
        # Password is configured (at minimum requirepass or ACL)
        auth_score=65
    fi
    # Check if protected-mode is on (available via INFO or config)
    local protected_mode
    protected_mode=$(redis_info_val "protected-mode" "")
    if [ -z "$protected_mode" ]; then
        # Try alternative field name
        protected_mode=$(redis_info_val "protected_mode" "")
    fi
    if [ -n "$EXTERNAL_REDIS_PASS" ]; then
        # Has auth; check if ACL users exist (heuristic: if we connected, auth works)
        auth_score=65
    elif [ "$protected_mode" = "yes" ]; then
        auth_score=35
    fi

    # --- B. TLS Configuration (30%) ---
    # Check for TLS port in server info
    local tls_port
    tls_port=$(redis_info_val "tls_port" "0")
    local tls_score=35  # default: assume private network, no TLS
    if [ "$tls_port" -gt 0 ] 2>/dev/null; then
        tls_score=100
    fi

    # --- C. Dangerous Commands (30%) ---
    # We cannot easily detect renamed commands from INFO
    # Default: assume commands are available (conservative)
    local danger_score=15

    # --- Final Security Score ---
    VALKEY_SCORE_SECURITY=$(_bc_int "$auth_score * 40 / 100 + $tls_score * 30 / 100 + $danger_score * 30 / 100")
    VALKEY_SCORE_SECURITY=$(_clamp "$VALKEY_SCORE_SECURITY")
}

# =============================================================================
# 8. CONFIGURATION BEST PRACTICES (Weight: 5%)
# =============================================================================
# Compliance-based: each check adds points up to 100
# =============================================================================
_valkey_score_config() {
    local config_score=0
    local maxmemory
    maxmemory=$(redis_info_val "maxmemory" "0")

    # 1. maxmemory-policy configured (not noeviction for caching) — 12 pts
    local policy="${VALKEY_MAXMEMORY_POLICY:-}"
    if [ -z "$policy" ]; then
        policy=$(redis_info_val "maxmemory_policy" "noeviction")
    fi
    if [ "$policy" != "noeviction" ]; then
        config_score=$((config_score + 12))
    fi

    # 2. tcp-backlog >= 511 — 11 pts (cannot check from INFO; give benefit of doubt)
    config_score=$((config_score + 11))

    # 3. timeout > 0 — 11 pts
    local timeout="${VALKEY_TIMEOUT:-0}"
    if [ "$timeout" -gt 0 ] 2>/dev/null; then
        config_score=$((config_score + 11))
    fi

    # 4. tcp-keepalive > 0 — 11 pts (usually default 300; assume ok if connected)
    config_score=$((config_score + 11))

    # 5. no-appendfsync-on-rewrite — 11 pts (cannot check; neutral)
    config_score=$((config_score + 11))

    # 6. hz >= 10 or dynamic-hz — 11 pts
    local hz="${VALKEY_HZ:-10}"
    if [ "$hz" -ge 10 ] 2>/dev/null; then
        config_score=$((config_score + 11))
    fi

    # 7. latency-monitor-threshold > 0 — 11 pts (cannot check; skip)

    # 8. slowlog-log-slower-than configured — 11 pts
    # If slowlog data exists (VALKEY_SLOWLOG_LEN is set), slowlog is configured
    if [ -n "$VALKEY_SLOWLOG_LEN" ]; then
        config_score=$((config_score + 11))
    fi

    # 9. persistence enabled (save or appendonly) — 11 pts
    local aof_enabled rdb_save_configured
    aof_enabled=$(redis_info_val "aof_enabled" "0")
    # rdb_last_save_time > 0 implies save is configured
    rdb_save_configured=$(redis_info_val "rdb_last_save_time" "0")
    if [ "$aof_enabled" = "1" ] || [ "$rdb_save_configured" -gt 0 ] 2>/dev/null; then
        config_score=$((config_score + 11))
    fi

    # Clamp to 0-100
    VALKEY_SCORE_CONFIG=$(_clamp "$config_score")
}

# =============================================================================
# ORCHESTRATOR — calculate_valkey_score
# =============================================================================
calculate_valkey_score() {
    # Early exit if Valkey is not connected or no data available
    if [ "${EXTERNAL_REDIS_STATUS:-}" != "connected" ] || [ -z "$VALKEY_RAW_DATA" ]; then
        VALKEY_SCORE=0
        VALKEY_SCORE_MEMORY=0
        VALKEY_SCORE_PERFORMANCE=0
        VALKEY_SCORE_REPLICATION=0
        VALKEY_SCORE_PERSISTENCE=0
        VALKEY_SCORE_CONNECTIONS=0
        VALKEY_SCORE_CLUSTER=0
        VALKEY_SCORE_SECURITY=0
        VALKEY_SCORE_CONFIG=0
        VALKEY_RATING_TEXT="N/A"
        VALKEY_RATING_EMOJI=""
        return 0
    fi

    log_info "Calculating Valkey/Redis scores..."

    # Run all category scorers
    _valkey_score_memory
    _valkey_score_performance
    _valkey_score_replication
    _valkey_score_persistence
    _valkey_score_connections
    _valkey_score_cluster
    _valkey_score_security
    _valkey_score_config

    # Weighted overall score
    VALKEY_SCORE=$(_bc_int "($VALKEY_SCORE_MEMORY * $VALKEY_WEIGHT_MEMORY + $VALKEY_SCORE_PERFORMANCE * $VALKEY_WEIGHT_PERFORMANCE + $VALKEY_SCORE_REPLICATION * $VALKEY_WEIGHT_REPLICATION + $VALKEY_SCORE_PERSISTENCE * $VALKEY_WEIGHT_PERSISTENCE + $VALKEY_SCORE_CONNECTIONS * $VALKEY_WEIGHT_CONNECTIONS + $VALKEY_SCORE_CLUSTER * $VALKEY_WEIGHT_CLUSTER + $VALKEY_SCORE_SECURITY * $VALKEY_WEIGHT_SECURITY + $VALKEY_SCORE_CONFIG * $VALKEY_WEIGHT_CONFIG) / 100")
    VALKEY_SCORE=$(_clamp "$VALKEY_SCORE")

    # Set rating text and emoji
    VALKEY_RATING_TEXT=$(get_rating_text "$VALKEY_SCORE")
    VALKEY_RATING_EMOJI=$(get_rating_emoji "$VALKEY_SCORE")

    log_success "Valkey scoring complete — Overall: ${VALKEY_SCORE}/100 (${VALKEY_RATING_TEXT})"
}
