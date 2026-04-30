#!/bin/bash
# =============================================================================
# 11_score_pg.sh - PostgreSQL Health Scoring (0-100 scale)
# =============================================================================
# 9 categories weighted per methodology doc:
#   Performance 15%, Availability & Connections 15%, Maintenance 15%,
#   Replication & Backup 15%, Resource Utilization 10%, Security 10%,
#   I/O & IOPS 10%, Index Health 5%, Configuration 5%
#
# Compatibility: Bash 3.2+ (no associative arrays, no namerefs)
# =============================================================================

# ---------------------------------------------------------------------------
# 1. Performance (15%)
#    Sub-weights: Cache 30%, Query 20%, Index Usage 20%, I/O Timing 15%,
#                 Temp Files 10%, Plan/Exec Ratio 5%
# ---------------------------------------------------------------------------
_pg_score_performance() {
    # A. Cache Hit Ratio (30%)
    local cache_hit
    cache_hit=$(json_val "$PG_RAW_DATA" "cache_hit_ratio" "0")
    local cache_score=25
    if (( $(echo "$cache_hit >= 99" | bc -l 2>/dev/null || echo 0) )); then cache_score=100
    elif (( $(echo "$cache_hit >= 95" | bc -l 2>/dev/null || echo 0) )); then cache_score=85
    elif (( $(echo "$cache_hit >= 90" | bc -l 2>/dev/null || echo 0) )); then cache_score=70
    elif (( $(echo "$cache_hit >= 80" | bc -l 2>/dev/null || echo 0) )); then cache_score=50
    fi

    # B. Query Performance (20%) - based on long-running queries as proxy
    #    (pg_stat_statements may not be available; use deadlocks + long queries)
    local deadlocks
    deadlocks=$(json_val "$PG_RAW_DATA" "deadlocks" "0")
    local query_score=100
    if [ "$deadlocks" -gt 10 ] 2>/dev/null; then query_score=10
    elif [ "$deadlocks" -gt 5 ] 2>/dev/null; then query_score=30
    elif [ "$deadlocks" -gt 2 ] 2>/dev/null; then query_score=50
    elif [ "$deadlocks" -gt 0 ] 2>/dev/null; then query_score=70
    fi

    # C. Index Usage Ratio (20%)
    local idx_ratio
    idx_ratio=$(json_val "$PG_RAW_DATA" "index_usage_ratio" "0")
    local idx_score=20
    if (( $(echo "$idx_ratio >= 95" | bc -l 2>/dev/null || echo 0) )); then idx_score=100
    elif (( $(echo "$idx_ratio >= 80" | bc -l 2>/dev/null || echo 0) )); then idx_score=80
    elif (( $(echo "$idx_ratio >= 60" | bc -l 2>/dev/null || echo 0) )); then idx_score=60
    elif (( $(echo "$idx_ratio >= 40" | bc -l 2>/dev/null || echo 0) )); then idx_score=40
    fi

    # D. I/O Timing Latency (15%) — avg block read time
    local track_io blks_read_val blk_read_time_val
    track_io=$(json_val "$PG_RAW_DATA" "track_io_timing" "off")
    blks_read_val=$(json_val "$PG_RAW_DATA" "blks_read" "0")
    blk_read_time_val=$(json_val "$PG_RAW_DATA" "blk_read_time" "0")
    local io_latency_score=50
    if [ "$track_io" = "on" ] && [ "${blks_read_val:-0}" -gt 0 ] 2>/dev/null; then
        local avg_read_ms
        avg_read_ms=$(echo "scale=4; $blk_read_time_val / $blks_read_val" | bc -l 2>/dev/null || echo "0")
        if (( $(echo "$avg_read_ms < 1" | bc -l 2>/dev/null || echo 0) )); then io_latency_score=100
        elif (( $(echo "$avg_read_ms < 5" | bc -l 2>/dev/null || echo 0) )); then io_latency_score=80
        elif (( $(echo "$avg_read_ms < 20" | bc -l 2>/dev/null || echo 0) )); then io_latency_score=60
        elif (( $(echo "$avg_read_ms < 50" | bc -l 2>/dev/null || echo 0) )); then io_latency_score=40
        else io_latency_score=20
        fi
    fi

    # E. Temp File Usage (10%)
    local temp_files
    temp_files=$(json_val "$PG_RAW_DATA" "temp_files" "0")
    local temp_bytes
    temp_bytes=$(json_val "$PG_RAW_DATA" "temp_bytes" "0")
    local temp_score=100
    local temp_mb=$(_bc_int "$temp_bytes / 1048576")
    if [ "$temp_mb" -gt 10240 ] 2>/dev/null; then temp_score=25
    elif [ "$temp_mb" -gt 1024 ] 2>/dev/null; then temp_score=50
    elif [ "$temp_mb" -gt 100 ] 2>/dev/null; then temp_score=70
    elif [ "$temp_mb" -gt 0 ] 2>/dev/null; then temp_score=85
    fi

    # F. Planning vs Execution Ratio (5%) — not always available, default 70
    local plan_exec_score=70

    # Weighted: 30+20+20+15+10+5 = 100
    local total
    total=$(( cache_score * 30 + query_score * 20 + idx_score * 20 + io_latency_score * 15 + temp_score * 10 + plan_exec_score * 5 ))
    echo $(( total / 100 ))
}

# ---------------------------------------------------------------------------
# 2. Availability & Connections (15%)
#    Sub-weights: Connection Util 30%, Idle 15%, Long-Running 15%,
#                 Lock Contention 20%, Idle-in-Transaction 20%
# ---------------------------------------------------------------------------
_pg_score_availability() {
    local conn_count max_conn idle_conn idle_in_txn long_queries deadlocks
    conn_count=$(json_val "$PG_RAW_DATA" "connection_count" "0")
    max_conn=$(json_val "$PG_RAW_DATA" "max_connections" "100")
    idle_conn=$(json_val "$PG_RAW_DATA" "idle_connections" "0")
    idle_in_txn=$(json_val "$PG_RAW_DATA" "idle_in_transaction" "0")
    long_queries=$(json_val "$PG_RAW_DATA" "long_running_queries" "0")
    deadlocks=$(json_val "$PG_RAW_DATA" "deadlocks" "0")

    # A. Connection Utilization (30%)
    local conn_util=0
    if [ "${max_conn:-0}" -gt 0 ] 2>/dev/null; then
        conn_util=$(_bc_int "$conn_count * 100 / $max_conn")
    fi
    local conn_score=100
    if [ "$conn_util" -gt 95 ] 2>/dev/null; then conn_score=10
    elif [ "$conn_util" -gt 85 ] 2>/dev/null; then conn_score=40
    elif [ "$conn_util" -gt 75 ] 2>/dev/null; then conn_score=60
    elif [ "$conn_util" -gt 60 ] 2>/dev/null; then conn_score=80
    fi

    # B. Idle Connections (15%)
    local idle_pct=0
    if [ "${conn_count:-0}" -gt 0 ] 2>/dev/null; then
        idle_pct=$(_bc_int "$idle_conn * 100 / $conn_count")
    fi
    local idle_score=100
    if [ "$idle_pct" -gt 80 ] 2>/dev/null; then idle_score=20
    elif [ "$idle_pct" -gt 60 ] 2>/dev/null; then idle_score=40
    elif [ "$idle_pct" -gt 40 ] 2>/dev/null; then idle_score=60
    elif [ "$idle_pct" -gt 20 ] 2>/dev/null; then idle_score=80
    fi

    # C. Long-Running Queries (15%)
    local lrq_score=100
    if [ "$long_queries" -gt 10 ] 2>/dev/null; then lrq_score=20
    elif [ "$long_queries" -gt 5 ] 2>/dev/null; then lrq_score=40
    elif [ "$long_queries" -gt 2 ] 2>/dev/null; then lrq_score=60
    elif [ "$long_queries" -gt 0 ] 2>/dev/null; then lrq_score=80
    fi

    # D. Lock Contention / Deadlocks (20%)
    local lock_score=100
    if [ "$deadlocks" -gt 10 ] 2>/dev/null; then lock_score=10
    elif [ "$deadlocks" -gt 5 ] 2>/dev/null; then lock_score=30
    elif [ "$deadlocks" -gt 2 ] 2>/dev/null; then lock_score=50
    elif [ "$deadlocks" -gt 0 ] 2>/dev/null; then lock_score=70
    fi

    # E. Idle-in-Transaction (20%)
    local iit_score=100
    if [ "$idle_in_txn" -gt 5 ] 2>/dev/null; then iit_score=20
    elif [ "$idle_in_txn" -gt 3 ] 2>/dev/null; then iit_score=50
    elif [ "$idle_in_txn" -gt 0 ] 2>/dev/null; then iit_score=75
    fi

    local total
    total=$(( conn_score * 30 + idle_score * 15 + lrq_score * 15 + lock_score * 20 + iit_score * 20 ))
    echo $(( total / 100 ))
}

# ---------------------------------------------------------------------------
# 3. Maintenance (15%)
#    Sub-weights: Vacuum 25%, Dead Tuples 25%, Bloat 15%, XID Age 15%,
#                 Checkpoint 15%, TOAST 5%
# ---------------------------------------------------------------------------
_pg_score_maintenance() {
    # A. Vacuum Freshness (25%) — not always available via PG_RAW_DATA
    #    Default to 70 (moderate) when data unavailable
    local vacuum_score=70

    # B. Dead Tuple Ratio (25%)
    local dead_ratio
    dead_ratio=$(json_val "$PG_RAW_DATA" "avg_dead_tuple_ratio" "0")
    local dead_score=100
    local dead_int
    dead_int=$(printf "%.0f" "$dead_ratio" 2>/dev/null || echo "0")
    if [ "$dead_int" -gt 50 ] 2>/dev/null; then dead_score=10
    elif [ "$dead_int" -gt 20 ] 2>/dev/null; then dead_score=40
    elif [ "$dead_int" -gt 10 ] 2>/dev/null; then dead_score=60
    elif [ "$dead_int" -gt 5 ] 2>/dev/null; then dead_score=80
    fi

    # C. Bloat Ratio (15%)
    local total_heap estimated_bloat
    total_heap=$(json_val "$PG_RAW_DATA" "total_heap_size_bytes" "0")
    estimated_bloat=$(json_val "$PG_RAW_DATA" "estimated_bloat_bytes" "0")
    local bloat_pct=0
    if [ "${total_heap:-0}" -gt 0 ] 2>/dev/null; then
        bloat_pct=$(_bc_int "$estimated_bloat * 100 / $total_heap")
    fi
    local bloat_score=100
    if [ "$bloat_pct" -gt 30 ] 2>/dev/null; then bloat_score=25
    elif [ "$bloat_pct" -gt 20 ] 2>/dev/null; then bloat_score=50
    elif [ "$bloat_pct" -gt 10 ] 2>/dev/null; then bloat_score=70
    elif [ "$bloat_pct" -gt 5 ] 2>/dev/null; then bloat_score=85
    fi

    # D. Transaction ID Age (15%)
    local xid_pct
    xid_pct=$(json_val "$PG_RAW_DATA" "xid_age_pct" "0")
    local xid_score=100
    local xid_int
    xid_int=$(printf "%.0f" "$xid_pct" 2>/dev/null || echo "0")
    if [ "$xid_int" -gt 75 ] 2>/dev/null; then xid_score=10
    elif [ "$xid_int" -gt 50 ] 2>/dev/null; then xid_score=40
    elif [ "$xid_int" -gt 25 ] 2>/dev/null; then xid_score=70
    fi

    # E. Checkpoint Efficiency (15%)
    local ckpt_timed ckpt_req ckpt_total
    ckpt_timed=$(json_val "$PG_RAW_DATA" "checkpoints_timed" "0")
    ckpt_req=$(json_val "$PG_RAW_DATA" "checkpoints_req" "0")
    ckpt_total=$(( ${ckpt_timed:-0} + ${ckpt_req:-0} ))
    local ckpt_score=100
    if [ "$ckpt_total" -gt 0 ] 2>/dev/null; then
        local ckpt_req_pct
        ckpt_req_pct=$(_bc_int "$ckpt_req * 100 / $ckpt_total")
        if [ "$ckpt_req_pct" -gt 75 ] 2>/dev/null; then ckpt_score=20
        elif [ "$ckpt_req_pct" -gt 50 ] 2>/dev/null; then ckpt_score=40
        elif [ "$ckpt_req_pct" -gt 25 ] 2>/dev/null; then ckpt_score=60
        elif [ "$ckpt_req_pct" -gt 10 ] 2>/dev/null; then ckpt_score=80
        fi
    fi

    # F. TOAST Health (5%) — default moderate when data unavailable
    local toast_score=70

    local total
    total=$(( vacuum_score * 25 + dead_score * 25 + bloat_score * 15 + xid_score * 15 + ckpt_score * 15 + toast_score * 5 ))
    echo $(( total / 100 ))
}

# ---------------------------------------------------------------------------
# 4. Replication & Backup (15%)
#    Sub-weights: Lag 40%, Standby 30%, Backup 30%
# ---------------------------------------------------------------------------
_pg_score_replication() {
    local is_replica repl_lag repl_count
    is_replica=$(json_val "$PG_RAW_DATA" "is_replica" "false")
    repl_lag=$(json_val "$PG_RAW_DATA" "replication_lag_bytes" "0")
    repl_count=$(json_val "$PG_RAW_DATA" "replication_count" "0")

    # Default: no replication configured — penalty score
    local lag_score=50
    local standby_score=50
    local backup_score=50

    if [ "$is_replica" = "true" ] || [ "${repl_count:-0}" -gt 0 ] 2>/dev/null; then
        # Lag scoring
        local lag_mb=$(_bc_int "${repl_lag:-0} / 1048576")
        lag_score=20
        if [ "$lag_mb" -lt 1 ] 2>/dev/null; then lag_score=100
        elif [ "$lag_mb" -lt 10 ] 2>/dev/null; then lag_score=85
        elif [ "$lag_mb" -lt 100 ] 2>/dev/null; then lag_score=70
        elif [ "$lag_mb" -lt 500 ] 2>/dev/null; then lag_score=50
        fi

        # Standby health
        if [ "$is_replica" = "true" ]; then
            standby_score=100  # we are a streaming replica
        elif [ "${repl_count:-0}" -gt 0 ] 2>/dev/null; then
            standby_score=100  # primary with replicas
        fi

        # Backup freshness — not directly available, default good if replication exists
        backup_score=75
    fi

    # Replication slots health bonus/penalty
    if [ "$JQ_AVAILABLE" = "true" ] && [ -n "$PG_REPL_SLOTS" ] && [ "$PG_REPL_SLOTS" != "[]" ] && [ "$PG_REPL_SLOTS" != "null" ]; then
        local inactive_slots
        inactive_slots=$(echo "$PG_REPL_SLOTS" | jq '[.[] | select(.active == false or .active == "f")] | length' 2>/dev/null || echo "0")
        if [ "${inactive_slots:-0}" -gt 0 ] 2>/dev/null; then
            # Inactive replication slots hold WAL and bloat pg_wal
            lag_score=$(( lag_score > 20 ? lag_score - 15 : lag_score ))
        fi
    fi

    lag_score=$(_clamp "$lag_score" 0 100)

    local total
    total=$(( lag_score * 40 + standby_score * 30 + backup_score * 30 ))
    echo $(( total / 100 ))
}

# ---------------------------------------------------------------------------
# 5. Resource Utilization (10%)
#    Sub-weights: DB Size 25%, Bloat 25%, WAL 25%, Connection reuse 25%
#    (CPU/Memory not available from PG catalogs alone)
# ---------------------------------------------------------------------------
_pg_score_resources() {
    # A. Database Size (25%)
    local all_db_size
    all_db_size=$(json_val "$PG_RAW_DATA" "all_databases_size_bytes" "0")
    local all_db_gb=$(_bc_int "${all_db_size:-0} / 1073741824")
    local size_score=100
    if [ "$all_db_gb" -gt 1024 ] 2>/dev/null; then size_score=20
    elif [ "$all_db_gb" -gt 500 ] 2>/dev/null; then size_score=40
    elif [ "$all_db_gb" -gt 100 ] 2>/dev/null; then size_score=60
    elif [ "$all_db_gb" -gt 50 ] 2>/dev/null; then size_score=80
    fi

    # B. Bloat Ratio (25%)
    local total_heap estimated_bloat
    total_heap=$(json_val "$PG_RAW_DATA" "total_heap_size_bytes" "0")
    estimated_bloat=$(json_val "$PG_RAW_DATA" "estimated_bloat_bytes" "0")
    local bloat_pct=0
    if [ "${total_heap:-0}" -gt 0 ] 2>/dev/null; then
        bloat_pct=$(_bc_int "$estimated_bloat * 100 / $total_heap")
    fi
    local bloat_score=100
    if [ "$bloat_pct" -gt 30 ] 2>/dev/null; then bloat_score=25
    elif [ "$bloat_pct" -gt 20 ] 2>/dev/null; then bloat_score=50
    elif [ "$bloat_pct" -gt 10 ] 2>/dev/null; then bloat_score=70
    elif [ "$bloat_pct" -gt 5 ] 2>/dev/null; then bloat_score=85
    fi

    # C. WAL Size relative to DB (25%)
    local wal_size
    wal_size=$(json_val "$PG_RAW_DATA" "wal_size_bytes" "0")
    local wal_score=100
    if [ "${all_db_size:-0}" -gt 0 ] 2>/dev/null && [ "${wal_size:-0}" -gt 0 ] 2>/dev/null; then
        local wal_pct=$(_bc_int "$wal_size * 100 / $all_db_size")
        if [ "$wal_pct" -gt 50 ] 2>/dev/null; then wal_score=40
        elif [ "$wal_pct" -gt 30 ] 2>/dev/null; then wal_score=60
        elif [ "$wal_pct" -gt 15 ] 2>/dev/null; then wal_score=80
        fi
    fi

    # D. Connection pressure reuse from availability (25%)
    local conn_count max_conn
    conn_count=$(json_val "$PG_RAW_DATA" "connection_count" "0")
    max_conn=$(json_val "$PG_RAW_DATA" "max_connections" "100")
    local conn_util=0
    if [ "${max_conn:-0}" -gt 0 ] 2>/dev/null; then
        conn_util=$(_bc_int "$conn_count * 100 / $max_conn")
    fi
    local conn_score=100
    if [ "$conn_util" -gt 95 ] 2>/dev/null; then conn_score=10
    elif [ "$conn_util" -gt 85 ] 2>/dev/null; then conn_score=40
    elif [ "$conn_util" -gt 75 ] 2>/dev/null; then conn_score=60
    elif [ "$conn_util" -gt 60 ] 2>/dev/null; then conn_score=80
    fi

    local total
    total=$(( size_score * 25 + bloat_score * 25 + wal_score * 25 + conn_score * 25 ))
    echo $(( total / 100 ))
}

# ---------------------------------------------------------------------------
# 6. Security (10%)
#    Sub-weights: SSL 35%, Superuser 35%, Password Policy 30%
# ---------------------------------------------------------------------------
_pg_score_security() {
    # A. SSL Usage (35%)
    local ssl_conn total_conn_ssl
    ssl_conn=$(json_val "$PG_RAW_DATA" "ssl_connections" "0")
    total_conn_ssl=$(json_val "$PG_RAW_DATA" "total_connections_ssl" "0")
    local ssl_pct=0
    if [ "${total_conn_ssl:-0}" -gt 0 ] 2>/dev/null; then
        ssl_pct=$(_bc_int "$ssl_conn * 100 / $total_conn_ssl")
    fi
    local ssl_score=20
    if [ "$ssl_pct" -eq 100 ] 2>/dev/null; then ssl_score=100
    elif [ "$ssl_pct" -ge 90 ] 2>/dev/null; then ssl_score=80
    elif [ "$ssl_pct" -ge 70 ] 2>/dev/null; then ssl_score=60
    elif [ "$ssl_pct" -ge 50 ] 2>/dev/null; then ssl_score=40
    fi

    # B. Superuser Management (35%)
    local superuser_count
    superuser_count=$(json_val "$PG_RAW_DATA" "superuser_count" "0")
    local su_score=100
    if [ "${superuser_count:-0}" -gt 10 ] 2>/dev/null; then su_score=20
    elif [ "${superuser_count:-0}" -gt 4 ] 2>/dev/null; then su_score=40
    elif [ "${superuser_count:-0}" -gt 2 ] 2>/dev/null; then su_score=60
    elif [ "${superuser_count:-0}" -gt 1 ] 2>/dev/null; then su_score=80
    fi

    # C. Password Policy (30%) — check via roles data if available
    local pw_score=50  # default moderate when data not available
    if [ "$JQ_AVAILABLE" = "true" ] && [ -n "$PG_ROLES_DATA" ] && [ "$PG_ROLES_DATA" != "[]" ] && [ "$PG_ROLES_DATA" != "null" ]; then
        pw_score=70
        # Check for roles with no password expiry or login with no password
        local roles_no_login_limit
        roles_no_login_limit=$(echo "$PG_ROLES_DATA" | jq '[.[] | select(.rolcanlogin == true and (.rolvaliduntil == null or .rolvaliduntil == "infinity"))] | length' 2>/dev/null || echo "0")
        if [ "${roles_no_login_limit:-0}" -eq 0 ] 2>/dev/null; then
            pw_score=100
        elif [ "${roles_no_login_limit:-0}" -le 2 ] 2>/dev/null; then
            pw_score=80
        elif [ "${roles_no_login_limit:-0}" -le 5 ] 2>/dev/null; then
            pw_score=60
        else
            pw_score=40
        fi
    fi

    local total
    total=$(( ssl_score * 35 + su_score * 35 + pw_score * 30 ))
    echo $(( total / 100 ))
}

# ---------------------------------------------------------------------------
# 7. I/O & IOPS (10%)
#    Sub-weights: Buffer Efficiency 25%, Block Latency 20%, Checkpoint 15%,
#                 Table Cache 15%, WAL I/O 10%, Index I/O 10%, I/O Config 5%
# ---------------------------------------------------------------------------
_pg_score_io() {
    # A. Buffer I/O Efficiency (25%)
    local buffers_backend_pct
    buffers_backend_pct=$(json_val "$PG_RAW_DATA" "buffers_backend_pct" "0")
    local buffer_io_score=70
    if [ "${buffers_backend_pct:-0}" -lt 5 ] 2>/dev/null; then buffer_io_score=100
    elif [ "${buffers_backend_pct:-0}" -lt 15 ] 2>/dev/null; then buffer_io_score=80
    elif [ "${buffers_backend_pct:-0}" -lt 30 ] 2>/dev/null; then buffer_io_score=60
    elif [ "${buffers_backend_pct:-0}" -lt 50 ] 2>/dev/null; then buffer_io_score=40
    elif [ "${buffers_backend_pct:-0}" -ge 50 ] 2>/dev/null; then buffer_io_score=20
    fi

    # B. Block Read Latency (20%)
    local track_io blks_read_val blk_read_time_val
    track_io=$(json_val "$PG_RAW_DATA" "track_io_timing" "off")
    blks_read_val=$(json_val "$PG_RAW_DATA" "blks_read" "0")
    blk_read_time_val=$(json_val "$PG_RAW_DATA" "blk_read_time" "0")
    local block_latency_score=50
    if [ "$track_io" = "on" ] && [ "${blks_read_val:-0}" -gt 0 ] 2>/dev/null; then
        local avg_read_ms
        avg_read_ms=$(echo "scale=4; $blk_read_time_val / $blks_read_val" | bc -l 2>/dev/null || echo "0")
        if (( $(echo "$avg_read_ms < 1" | bc -l 2>/dev/null || echo 0) )); then block_latency_score=100
        elif (( $(echo "$avg_read_ms < 5" | bc -l 2>/dev/null || echo 0) )); then block_latency_score=80
        elif (( $(echo "$avg_read_ms < 20" | bc -l 2>/dev/null || echo 0) )); then block_latency_score=60
        elif (( $(echo "$avg_read_ms < 50" | bc -l 2>/dev/null || echo 0) )); then block_latency_score=40
        else block_latency_score=20
        fi
    fi

    # C. Checkpoint Efficiency (15%)
    local ckpt_timed ckpt_req ckpt_total
    ckpt_timed=$(json_val "$PG_RAW_DATA" "checkpoints_timed" "0")
    ckpt_req=$(json_val "$PG_RAW_DATA" "checkpoints_req" "0")
    ckpt_total=$(( ${ckpt_timed:-0} + ${ckpt_req:-0} ))
    local checkpoint_io_score=100
    if [ "$ckpt_total" -gt 0 ] 2>/dev/null; then
        local ckpt_req_pct
        ckpt_req_pct=$(_bc_int "$ckpt_req * 100 / $ckpt_total")
        if [ "$ckpt_req_pct" -gt 75 ] 2>/dev/null; then checkpoint_io_score=20
        elif [ "$ckpt_req_pct" -gt 50 ] 2>/dev/null; then checkpoint_io_score=40
        elif [ "$ckpt_req_pct" -gt 25 ] 2>/dev/null; then checkpoint_io_score=60
        elif [ "$ckpt_req_pct" -gt 10 ] 2>/dev/null; then checkpoint_io_score=80
        fi
    fi

    # D. Per-Table Cache Hit (15%)
    local table_cache_score=85
    if [ "$JQ_AVAILABLE" = "true" ] && [ -n "$PG_TABLE_IO_DATA" ] && [ "$PG_TABLE_IO_DATA" != "[]" ]; then
        local min_table_cache_hit
        min_table_cache_hit=$(echo "$PG_TABLE_IO_DATA" | jq '[.[] | select(.heap_blks_read > 100)] | if length > 0 then [.[].heap_cache_hit_pct] | min else 100 end' 2>/dev/null || echo "100")
        local min_hit_int
        min_hit_int=$(printf "%.0f" "$min_table_cache_hit" 2>/dev/null || echo "100")
        if [ "$min_hit_int" -ge 99 ] 2>/dev/null; then table_cache_score=100
        elif [ "$min_hit_int" -ge 95 ] 2>/dev/null; then table_cache_score=85
        elif [ "$min_hit_int" -ge 90 ] 2>/dev/null; then table_cache_score=70
        elif [ "$min_hit_int" -ge 80 ] 2>/dev/null; then table_cache_score=50
        else table_cache_score=25
        fi
    fi

    # E. WAL I/O Performance (10%) — PG14+, default 70 if unavailable
    local wal_io_score=70
    if [ "$JQ_AVAILABLE" = "true" ] && [ -n "$PG_WAL_IO_DATA" ] && [ "$PG_WAL_IO_DATA" != "{}" ]; then
        local avg_wal_sync
        avg_wal_sync=$(echo "$PG_WAL_IO_DATA" | jq -r '.avg_wal_sync_ms // 0' 2>/dev/null || echo "0")
        if [ "$avg_wal_sync" != "0" ] && [ "$avg_wal_sync" != "null" ]; then
            if (( $(echo "$avg_wal_sync < 1" | bc -l 2>/dev/null || echo 0) )); then wal_io_score=100
            elif (( $(echo "$avg_wal_sync < 5" | bc -l 2>/dev/null || echo 0) )); then wal_io_score=80
            elif (( $(echo "$avg_wal_sync < 20" | bc -l 2>/dev/null || echo 0) )); then wal_io_score=60
            elif (( $(echo "$avg_wal_sync < 50" | bc -l 2>/dev/null || echo 0) )); then wal_io_score=40
            else wal_io_score=20
            fi
        fi
    fi

    # F. Index I/O Efficiency (10%)
    local index_io_score=85
    if [ "$JQ_AVAILABLE" = "true" ] && [ -n "$PG_INDEX_IO_DATA" ] && [ "$PG_INDEX_IO_DATA" != "[]" ]; then
        local min_idx_cache_hit
        min_idx_cache_hit=$(echo "$PG_INDEX_IO_DATA" | jq '[.[] | select(.idx_blks_read > 100)] | if length > 0 then [.[].idx_cache_hit_pct] | min else 100 end' 2>/dev/null || echo "100")
        local min_idx_int
        min_idx_int=$(printf "%.0f" "$min_idx_cache_hit" 2>/dev/null || echo "100")
        if [ "$min_idx_int" -ge 99 ] 2>/dev/null; then index_io_score=100
        elif [ "$min_idx_int" -ge 95 ] 2>/dev/null; then index_io_score=85
        elif [ "$min_idx_int" -ge 90 ] 2>/dev/null; then index_io_score=70
        elif [ "$min_idx_int" -ge 80 ] 2>/dev/null; then index_io_score=50
        else index_io_score=25
        fi
    fi

    # G. I/O Configuration (5%)
    local io_config_score=30
    if [ "$track_io" = "on" ]; then io_config_score=100; fi

    local total
    total=$(( buffer_io_score * 25 + block_latency_score * 20 + checkpoint_io_score * 15 + table_cache_score * 15 + wal_io_score * 10 + index_io_score * 10 + io_config_score * 5 ))
    echo $(( total / 100 ))
}

# ---------------------------------------------------------------------------
# 8. Index Health (5%)
#    Sub-weights: Unused 30%, Invalid 25%, Bloat 20%, Size Efficiency 15%,
#                 Per-Index Cache Hit 10%
# ---------------------------------------------------------------------------
_pg_score_index() {
    # A. Unused Indexes (30%)
    local unused_idx
    unused_idx=$(json_val "$PG_RAW_DATA" "unused_indexes" "0")
    local unused_score=100
    if [ "${unused_idx:-0}" -gt 30 ] 2>/dev/null; then unused_score=20
    elif [ "${unused_idx:-0}" -gt 15 ] 2>/dev/null; then unused_score=40
    elif [ "${unused_idx:-0}" -gt 5 ] 2>/dev/null; then unused_score=60
    elif [ "${unused_idx:-0}" -gt 0 ] 2>/dev/null; then unused_score=80
    fi

    # B. Invalid Indexes (25%)
    local invalid_idx
    invalid_idx=$(json_val "$PG_RAW_DATA" "invalid_indexes" "0")
    local invalid_score=100
    if [ "${invalid_idx:-0}" -gt 5 ] 2>/dev/null; then invalid_score=0
    elif [ "${invalid_idx:-0}" -gt 2 ] 2>/dev/null; then invalid_score=30
    elif [ "${invalid_idx:-0}" -gt 0 ] 2>/dev/null; then invalid_score=60
    fi

    # C. Index Bloat (20%) — estimated from index vs table size ratio
    local total_index_size total_heap_size
    total_index_size=$(json_val "$PG_RAW_DATA" "total_index_size_bytes" "0")
    total_heap_size=$(json_val "$PG_RAW_DATA" "total_heap_size_bytes" "0")
    local idx_bloat_score=80
    if [ "${total_heap_size:-0}" -gt 0 ] 2>/dev/null && [ "${total_index_size:-0}" -gt 0 ] 2>/dev/null; then
        local idx_to_heap_pct=$(_bc_int "$total_index_size * 100 / $total_heap_size")
        if [ "$idx_to_heap_pct" -lt 50 ] 2>/dev/null; then idx_bloat_score=100
        elif [ "$idx_to_heap_pct" -lt 100 ] 2>/dev/null; then idx_bloat_score=80
        elif [ "$idx_to_heap_pct" -lt 200 ] 2>/dev/null; then idx_bloat_score=60
        elif [ "$idx_to_heap_pct" -lt 400 ] 2>/dev/null; then idx_bloat_score=40
        else idx_bloat_score=20
        fi
    fi

    # D. Size Efficiency (15%) — index to table ratio
    local size_eff_score="$idx_bloat_score"

    # E. Per-Index Cache Hit (10%)
    local idx_cache_score=85
    if [ "$JQ_AVAILABLE" = "true" ] && [ -n "$PG_INDEX_IO_DATA" ] && [ "$PG_INDEX_IO_DATA" != "[]" ]; then
        local min_idx_hit
        min_idx_hit=$(echo "$PG_INDEX_IO_DATA" | jq '[.[] | select(.idx_blks_read > 100)] | if length > 0 then [.[].idx_cache_hit_pct] | min else 100 end' 2>/dev/null || echo "100")
        local min_idx_int
        min_idx_int=$(printf "%.0f" "$min_idx_hit" 2>/dev/null || echo "100")
        if [ "$min_idx_int" -ge 99 ] 2>/dev/null; then idx_cache_score=100
        elif [ "$min_idx_int" -ge 95 ] 2>/dev/null; then idx_cache_score=85
        elif [ "$min_idx_int" -ge 90 ] 2>/dev/null; then idx_cache_score=70
        elif [ "$min_idx_int" -ge 80 ] 2>/dev/null; then idx_cache_score=50
        else idx_cache_score=25
        fi
    fi

    local total
    total=$(( unused_score * 30 + invalid_score * 25 + idx_bloat_score * 20 + size_eff_score * 15 + idx_cache_score * 10 ))
    echo $(( total / 100 ))
}

# ---------------------------------------------------------------------------
# 9. Configuration (5%)
#    Compliance-based: each check adds points up to 100
# ---------------------------------------------------------------------------
_pg_score_config() {
    local config_score=0

    # shared_buffers set (15 pts)
    local shared_buffers
    shared_buffers=$(json_val "$PG_RAW_DATA" "shared_buffers" "0")
    if [ "${shared_buffers:-0}" != "0" ] && [ "${shared_buffers:-0}" != "null" ] && [ -n "${shared_buffers}" ]; then
        config_score=$(( config_score + 15 ))
    fi

    # effective_cache_size set (15 pts)
    local eff_cache
    eff_cache=$(json_val "$PG_RAW_DATA" "effective_cache_size" "0")
    if [ "${eff_cache:-0}" != "0" ] && [ "${eff_cache:-0}" != "null" ] && [ -n "${eff_cache}" ]; then
        config_score=$(( config_score + 15 ))
    fi

    # work_mem set (10 pts)
    local work_mem
    work_mem=$(json_val "$PG_RAW_DATA" "work_mem" "0")
    if [ "${work_mem:-0}" != "0" ] && [ "${work_mem:-0}" != "null" ] && [ -n "${work_mem}" ]; then
        config_score=$(( config_score + 10 ))
    fi

    # checkpoint_completion_target >= 0.9 (10 pts)
    local ckpt_target
    ckpt_target=$(json_val "$PG_RAW_DATA" "checkpoint_completion_target" "0")
    if [ -n "$ckpt_target" ] && [ "$ckpt_target" != "0" ] && [ "$ckpt_target" != "null" ]; then
        config_score=$(( config_score + 5 ))
        if (( $(echo "$ckpt_target >= 0.9" | bc -l 2>/dev/null || echo 0) )); then
            config_score=$(( config_score + 5 ))
        fi
    fi

    # track_io_timing = on (10 pts)
    local track_io
    track_io=$(json_val "$PG_RAW_DATA" "track_io_timing" "off")
    if [ "$track_io" = "on" ]; then
        config_score=$(( config_score + 10 ))
    fi

    # maintenance_work_mem / random_page_cost / log settings — awarded if
    # shared_buffers and effective_cache_size both present (heuristic: tuned DB)
    if [ "${shared_buffers:-0}" != "0" ] && [ "${eff_cache:-0}" != "0" ]; then
        config_score=$(( config_score + 10 ))
    fi

    # pg_stat_statements enabled — check tables_count as proxy for active DB
    local tables_count
    tables_count=$(json_val "$PG_RAW_DATA" "tables_count" "0")
    if [ "${tables_count:-0}" -gt 0 ] 2>/dev/null; then
        config_score=$(( config_score + 10 ))
    fi

    # log_statement / log_min_duration_statement — bonus points
    config_score=$(( config_score + 15 ))

    # Clamp to 0-100
    config_score=$(_clamp "$config_score" 0 100)

    echo "$config_score"
}

# =============================================================================
# Orchestrator
# =============================================================================
calculate_postgres_score() {
    # Early exit: no connection or no data
    if [ "$EXTERNAL_PG_STATUS" != "connected" ] || [ -z "$PG_RAW_DATA" ]; then
        PG_SCORE=0
        PG_RATING_TEXT="N/A"
        PG_RATING_EMOJI="⚪"
        return 0
    fi

    # Compute each category
    DB_SCORE_PG_performance=$(_pg_score_performance)
    DB_SCORE_PG_availability=$(_pg_score_availability)
    DB_SCORE_PG_maintenance=$(_pg_score_maintenance)
    DB_SCORE_PG_replication=$(_pg_score_replication)
    DB_SCORE_PG_resources=$(_pg_score_resources)
    DB_SCORE_PG_security=$(_pg_score_security)
    DB_SCORE_PG_io=$(_pg_score_io)
    DB_SCORE_PG_indexes=$(_pg_score_index)
    DB_SCORE_PG_config=$(_pg_score_config)

    # Clamp all sub-scores
    DB_SCORE_PG_performance=$(_clamp "${DB_SCORE_PG_performance:-0}" 0 100)
    DB_SCORE_PG_availability=$(_clamp "${DB_SCORE_PG_availability:-0}" 0 100)
    DB_SCORE_PG_maintenance=$(_clamp "${DB_SCORE_PG_maintenance:-0}" 0 100)
    DB_SCORE_PG_replication=$(_clamp "${DB_SCORE_PG_replication:-0}" 0 100)
    DB_SCORE_PG_resources=$(_clamp "${DB_SCORE_PG_resources:-0}" 0 100)
    DB_SCORE_PG_security=$(_clamp "${DB_SCORE_PG_security:-0}" 0 100)
    DB_SCORE_PG_io=$(_clamp "${DB_SCORE_PG_io:-0}" 0 100)
    DB_SCORE_PG_indexes=$(_clamp "${DB_SCORE_PG_indexes:-0}" 0 100)
    DB_SCORE_PG_config=$(_clamp "${DB_SCORE_PG_config:-0}" 0 100)

    # Weighted average per methodology:
    #   Performance 15%, Availability 15%, Maintenance 15%, Replication 15%,
    #   Resources 10%, Security 10%, I/O 10%, Index 5%, Config 5%
    local weighted_total
    weighted_total=$(( \
        DB_SCORE_PG_performance * 15 + \
        DB_SCORE_PG_availability * 15 + \
        DB_SCORE_PG_maintenance  * 15 + \
        DB_SCORE_PG_replication  * 15 + \
        DB_SCORE_PG_resources    * 10 + \
        DB_SCORE_PG_security     * 10 + \
        DB_SCORE_PG_io           * 10 + \
        DB_SCORE_PG_indexes      *  5 + \
        DB_SCORE_PG_config       *  5   \
    ))
    DB_SCORE_PG_overall=$(( weighted_total / 100 ))
    DB_SCORE_PG_overall=$(_clamp "$DB_SCORE_PG_overall" 0 100)

    PG_SCORE="$DB_SCORE_PG_overall"
    PG_RATING_TEXT=$(get_rating_text "$PG_SCORE")
    PG_RATING_EMOJI=$(get_rating_emoji "$PG_SCORE")
    log_success "PostgreSQL scoring complete — Overall: ${PG_SCORE}/100 (${PG_RATING_TEXT})"
}
