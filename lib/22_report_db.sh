#!/bin/bash
# =============================================================================
# 22_report_db.sh - External Database Report Sections (Markdown)
# =============================================================================
# Part of the Lerian Infrastructure Scoring Tool v2.
#
# Generates report sections for all 4 external databases:
#   - PostgreSQL, MongoDB, Valkey/Redis, RabbitMQ
# Plus an overview table and the Grand Unified Score section.
#
# Each function is self-contained, outputs markdown to stdout, and is
# guarded by connection-status checks so it safely no-ops when data
# is unavailable.
#
# Dependencies:
#   - 00_constants.sh (global variables, weights)
#   - 01_util.sh      (json_val, redis_info_val, get_rating_text,
#                       get_rating_emoji, get_rating_bar, format_bytes, trim)
#   - 04_collect_pg.sh .. 07_collect_rabbit.sh  (raw data globals)
#   - 11_score_pg.sh  .. 15_score_unified.sh    (score globals)
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

# -----------------------------------------------------------------------------
# Inline byte formatter — works even when format_bytes is unavailable
# -----------------------------------------------------------------------------
_fmt_bytes() {
    local bytes="${1:-0}"
    # Guard against non-numeric input
    if ! echo "$bytes" | grep -qE '^[0-9]+$' 2>/dev/null; then
        echo "${bytes} B"
        return
    fi
    if [ "$bytes" -gt 0 ] 2>/dev/null; then
        echo "$bytes" | awk '{
            if ($1 >= 1073741824) printf "%.1f GB", $1/1073741824;
            else if ($1 >= 1048576) printf "%.1f MB", $1/1048576;
            else if ($1 >= 1024) printf "%.1f KB", $1/1024;
            else printf "%d B", $1
        }'
    else
        echo "0 B"
    fi
}

# -----------------------------------------------------------------------------
# Helper: format a percentage safely
# -----------------------------------------------------------------------------
_fmt_pct() {
    local val="${1:-0}"
    printf "%.1f%%" "$val" 2>/dev/null || echo "${val}%"
}

# -----------------------------------------------------------------------------
# Helper: print a score row with bar and emoji for category tables
# -----------------------------------------------------------------------------
_db_score_row() {
    local category="$1"
    local score="$2"
    local weight="$3"
    local bar emoji rating
    bar=$(get_rating_bar "$score")
    emoji=$(get_rating_emoji "$score")
    rating=$(get_rating_text "$score")
    echo "| $category | ${score}/100 | ${weight}% | $bar $emoji $rating |"
}

# =============================================================================
# 1. report_db_overview() — Overview table of all external databases
# =============================================================================
report_db_overview() {
    echo "## $(lang_get "db_external_health")"
    echo ""
    echo "> Overview of external database connections and health scores."
    echo ""
    echo "| $(lang_get "th_database") | $(lang_get "th_status") | $(lang_get "th_score") | $(lang_get "th_rating") |"
    echo "|----------|--------|-------|--------|"

    # PostgreSQL
    if [ "${EXTERNAL_PG_STATUS:-not_checked}" = "connected" ] && [ -n "$PG_RAW_DATA" ]; then
        echo "| PostgreSQL | $(lang_get "status_connected") | ${PG_SCORE:-0}/100 | $(get_rating_emoji "${PG_SCORE:-0}") $(get_rating_text "${PG_SCORE:-0}") |"
    elif [ "${EXTERNAL_PG_STATUS:-not_checked}" != "not_checked" ]; then
        echo "| PostgreSQL | $(lang_get "status_disconnected") | -/100 | -- $(lang_get "status_unavailable") |"
    else
        echo "| PostgreSQL | $(lang_get "status_not_configured") | -/100 | -- $(lang_get "status_skipped") |"
    fi

    # MongoDB
    if [ "${EXTERNAL_MONGO_STATUS:-not_checked}" = "connected" ] && [ -n "$MONGO_RAW_DATA" ]; then
        echo "| MongoDB | $(lang_get "status_connected") | ${MONGO_SCORE:-0}/100 | $(get_rating_emoji "${MONGO_SCORE:-0}") $(get_rating_text "${MONGO_SCORE:-0}") |"
    elif [ "${EXTERNAL_MONGO_STATUS:-not_checked}" != "not_checked" ]; then
        echo "| MongoDB | $(lang_get "status_disconnected") | -/100 | -- $(lang_get "status_unavailable") |"
    else
        echo "| MongoDB | $(lang_get "status_not_configured") | -/100 | -- $(lang_get "status_skipped") |"
    fi

    # Valkey/Redis
    if [ "${EXTERNAL_REDIS_STATUS:-not_checked}" = "connected" ] && [ -n "$VALKEY_RAW_DATA" ]; then
        echo "| Valkey/Redis | $(lang_get "status_connected") | ${VALKEY_SCORE:-0}/100 | $(get_rating_emoji "${VALKEY_SCORE:-0}") $(get_rating_text "${VALKEY_SCORE:-0}") |"
    elif [ "${EXTERNAL_REDIS_STATUS:-not_checked}" != "not_checked" ]; then
        echo "| Valkey/Redis | $(lang_get "status_disconnected") | -/100 | -- $(lang_get "status_unavailable") |"
    else
        echo "| Valkey/Redis | $(lang_get "status_not_configured") | -/100 | -- $(lang_get "status_skipped") |"
    fi

    # RabbitMQ
    if [ "${EXTERNAL_RABBITMQ_STATUS:-not_checked}" = "connected" ] && [ -n "$RMQ_RAW_DATA" ]; then
        echo "| RabbitMQ | $(lang_get "status_connected") | ${RMQ_SCORE:-0}/100 | $(get_rating_emoji "${RMQ_SCORE:-0}") $(get_rating_text "${RMQ_SCORE:-0}") |"
    elif [ "${EXTERNAL_RABBITMQ_STATUS:-not_checked}" != "not_checked" ]; then
        echo "| RabbitMQ | $(lang_get "status_disconnected") | -/100 | -- $(lang_get "status_unavailable") |"
    else
        echo "| RabbitMQ | $(lang_get "status_not_configured") | -/100 | -- $(lang_get "status_skipped") |"
    fi

    echo ""
    echo "---"
    echo ""
}

# =============================================================================
# 2. report_postgres() — PostgreSQL detailed report section
# =============================================================================
report_postgres() {
    # Guard: skip if not connected
    if [ "${EXTERNAL_PG_STATUS:-not_checked}" != "connected" ] || [ -z "$PG_RAW_DATA" ]; then
        return
    fi

    echo "## $(lang_get "db_pg_report")"
    echo ""

    # ---- Connection & Version Info ----
    local pg_version pg_host pg_port pg_database
    pg_version=$(json_val "$PG_RAW_DATA" "server_version" "\"unknown\"")
    pg_host="${EXTERNAL_PG_HOST:-unknown}"
    pg_port="${EXTERNAL_PG_PORT:-5432}"
    pg_database="${EXTERNAL_PG_DATABASES:-unknown}"

    echo "### $(lang_get "db_connection_info")"
    echo ""
    echo "| $(lang_get "th_property") | $(lang_get "th_value") |"
    echo "|----------|-------|"
    echo "| **$(lang_get "label_version")** | \`${pg_version}\` |"
    echo "| **$(lang_get "label_host")** | \`${pg_host}:${pg_port}\` |"
    echo "| **$(lang_get "label_database")** | \`${pg_database}\` |"
    echo "| **$(lang_get "th_overall_score")** | **${PG_SCORE:-0}/100** $(get_rating_emoji "${PG_SCORE:-0}") $(get_rating_text "${PG_SCORE:-0}") |"
    echo ""

    # ---- Key Metrics Table ----
    local cache_hit idx_usage conn_count max_conn idle_conn deadlocks temp_bytes dead_ratio db_size
    cache_hit=$(json_val "$PG_RAW_DATA" "cache_hit_ratio" "0")
    idx_usage=$(json_val "$PG_RAW_DATA" "index_usage_ratio" "0")
    conn_count=$(json_val "$PG_RAW_DATA" "connection_count" "0")
    max_conn=$(json_val "$PG_RAW_DATA" "max_connections" "0")
    idle_conn=$(json_val "$PG_RAW_DATA" "idle_connections" "0")
    deadlocks=$(json_val "$PG_RAW_DATA" "deadlocks" "0")
    temp_bytes=$(json_val "$PG_RAW_DATA" "temp_bytes" "0")
    dead_ratio=$(json_val "$PG_RAW_DATA" "avg_dead_tuple_ratio" "0")
    db_size=$(json_val "$PG_RAW_DATA" "database_size_bytes" "0")

    echo "### $(lang_get "db_key_metrics")"
    echo ""
    echo "| $(lang_get "th_metric") | $(lang_get "th_value") | $(lang_get "th_status") |"
    echo "|--------|-------|--------|"

    # Cache hit ratio
    local cache_status="$(get_rating_emoji 50) $(lang_get "status_low")"
    if (( $(echo "$cache_hit >= 99" | bc -l 2>/dev/null || echo 0) )); then cache_status="$(get_rating_emoji 95) $(get_rating_text 95)"
    elif (( $(echo "$cache_hit >= 95" | bc -l 2>/dev/null || echo 0) )); then cache_status="$(get_rating_emoji 80) $(get_rating_text 80)"
    elif (( $(echo "$cache_hit >= 90" | bc -l 2>/dev/null || echo 0) )); then cache_status="$(get_rating_emoji 65) $(get_rating_text 65)"
    fi
    echo "| $(lang_get "metric_cache_hit_ratio") | $(_fmt_pct "$cache_hit") | $cache_status |"

    # Index usage ratio
    local idx_status="$(get_rating_emoji 50) $(lang_get "status_low")"
    if (( $(echo "$idx_usage >= 95" | bc -l 2>/dev/null || echo 0) )); then idx_status="$(get_rating_emoji 95) $(get_rating_text 95)"
    elif (( $(echo "$idx_usage >= 80" | bc -l 2>/dev/null || echo 0) )); then idx_status="$(get_rating_emoji 80) $(get_rating_text 80)"
    elif (( $(echo "$idx_usage >= 60" | bc -l 2>/dev/null || echo 0) )); then idx_status="$(get_rating_emoji 65) $(get_rating_text 65)"
    fi
    echo "| $(lang_get "metric_index_usage_ratio") | $(_fmt_pct "$idx_usage") | $idx_status |"

    # Connections
    local conn_pct=0
    if [ "${max_conn:-0}" -gt 0 ] 2>/dev/null; then
        conn_pct=$(echo "scale=1; $conn_count * 100 / $max_conn" | bc -l 2>/dev/null || echo "0")
    fi
    local conn_status="$(get_rating_emoji 80) $(lang_get "status_ok")"
    if (( $(echo "$conn_pct > 85" | bc -l 2>/dev/null || echo 0) )); then conn_status="$(get_rating_emoji 30) $(lang_get "status_critical")"
    elif (( $(echo "$conn_pct > 75" | bc -l 2>/dev/null || echo 0) )); then conn_status="$(get_rating_emoji 55) $(lang_get "status_warning")"
    fi
    echo "| $(lang_get "metric_connections") | ${conn_count}/${max_conn} ($(_fmt_pct "$conn_pct")) | $conn_status |"

    # Idle connections
    echo "| $(lang_get "metric_idle_connections") | ${idle_conn} | $(get_rating_emoji 80) |"

    # Deadlocks
    local dl_status="$(get_rating_emoji 95) $(lang_get "status_none")"
    if [ "${deadlocks:-0}" -gt 5 ] 2>/dev/null; then dl_status="$(get_rating_emoji 30) $(lang_get "status_critical")"
    elif [ "${deadlocks:-0}" -gt 0 ] 2>/dev/null; then dl_status="$(get_rating_emoji 65) $(lang_get "status_warning")"
    fi
    echo "| $(lang_get "metric_deadlocks") | ${deadlocks} | $dl_status |"

    # Temp bytes
    echo "| $(lang_get "metric_temp_bytes_written") | $(_fmt_bytes "$temp_bytes") | |"

    # Dead tuple ratio
    local dt_status="$(get_rating_emoji 80) $(lang_get "status_ok")"
    local dead_int
    dead_int=$(printf "%.0f" "$dead_ratio" 2>/dev/null || echo "0")
    if [ "${dead_int:-0}" -gt 20 ] 2>/dev/null; then dt_status="$(get_rating_emoji 30) $(lang_get "status_high")"
    elif [ "${dead_int:-0}" -gt 10 ] 2>/dev/null; then dt_status="$(get_rating_emoji 55) $(lang_get "status_elevated")"
    fi
    echo "| $(lang_get "metric_avg_dead_tuple_ratio") | $(_fmt_pct "$dead_ratio") | $dt_status |"

    # Database size
    echo "| $(lang_get "metric_database_size") | $(_fmt_bytes "$db_size") | |"

    echo ""

    # ---- Storage Breakdown ----
    local all_db_size total_heap total_index
    all_db_size=$(json_val "$PG_RAW_DATA" "all_databases_size_bytes" "0")
    total_heap=$(json_val "$PG_RAW_DATA" "total_heap_size_bytes" "0")
    total_index=$(json_val "$PG_RAW_DATA" "total_index_size_bytes" "0")

    if [ "${all_db_size:-0}" -gt 0 ] 2>/dev/null || [ "${total_heap:-0}" -gt 0 ] 2>/dev/null; then
        echo "### $(lang_get "db_storage_breakdown")"
        echo ""
        echo "| $(lang_get "th_component") | $(lang_get "th_size") |"
        echo "|-----------|------|"
        if [ "${all_db_size:-0}" -gt 0 ] 2>/dev/null; then
            echo "| $(lang_get "storage_all_databases") | $(_fmt_bytes "$all_db_size") |"
        fi
        if [ "${total_heap:-0}" -gt 0 ] 2>/dev/null; then
            echo "| $(lang_get "storage_heap") | $(_fmt_bytes "$total_heap") |"
        fi
        if [ "${total_index:-0}" -gt 0 ] 2>/dev/null; then
            echo "| $(lang_get "storage_indexes") | $(_fmt_bytes "$total_index") |"
        fi
        echo ""
    fi

    # ---- Top Tables ----
    if [ "$JQ_AVAILABLE" = "true" ] && [ -n "$PG_RAW_DATA" ]; then
        local top_tables
        top_tables=$(echo "$PG_RAW_DATA" | jq -r '.top_tables // empty' 2>/dev/null || echo "")
        if [ -n "$top_tables" ] && [ "$top_tables" != "null" ] && [ "$top_tables" != "[]" ]; then
            local table_count
            table_count=$(echo "$top_tables" | jq 'length' 2>/dev/null || echo "0")
            if [ "${table_count:-0}" -gt 0 ] 2>/dev/null; then
                echo "### $(lang_get "db_top_tables")"
                echo ""
                echo "| $(lang_get "th_table") | $(lang_get "th_total_size") | $(lang_get "th_dead_tuples") |"
                echo "|-------|-----------|---------------|"
                local t=0
                while [ "$t" -lt "$table_count" ] && [ "$t" -lt 10 ]; do
                    local tname tsize tdead
                    tname=$(echo "$top_tables" | jq -r ".[$t].table_name // \"unknown\"" 2>/dev/null || echo "unknown")
                    tsize=$(echo "$top_tables" | jq -r ".[$t].total_size_bytes // 0" 2>/dev/null || echo "0")
                    tdead=$(echo "$top_tables" | jq -r ".[$t].dead_tuple_ratio // 0" 2>/dev/null || echo "0")
                    echo "| \`${tname}\` | $(_fmt_bytes "$tsize") | $(_fmt_pct "$tdead") |"
                    t=$((t + 1))
                done
                echo ""
            fi
        fi
    fi

    # ---- Category Score Breakdown ----
    echo "### $(lang_get "category_scores")"
    echo ""
    echo "| $(lang_get "th_category") | $(lang_get "th_score") | $(lang_get "th_weight") | $(lang_get "th_rating") |"
    echo "|----------|-------|--------|--------|"
    _db_score_row "$(lang_get "cat_performance")"      "${DB_SCORE_PG_performance:-0}"  "${PG_WEIGHT_PERFORMANCE:-15}"
    _db_score_row "$(lang_get "cat_availability")"     "${DB_SCORE_PG_availability:-0}" "${PG_WEIGHT_AVAILABILITY:-15}"
    _db_score_row "$(lang_get "cat_maintenance")"      "${DB_SCORE_PG_maintenance:-0}"  "${PG_WEIGHT_MAINTENANCE:-15}"
    _db_score_row "$(lang_get "cat_replication")"      "${DB_SCORE_PG_replication:-0}"  "${PG_WEIGHT_REPLICATION:-15}"
    _db_score_row "$(lang_get "cat_resource_util")"    "${DB_SCORE_PG_resources:-0}"    "${PG_WEIGHT_RESOURCES:-10}"
    _db_score_row "$(lang_get "cat_db_security")"      "${DB_SCORE_PG_security:-0}"     "${PG_WEIGHT_SECURITY:-10}"
    _db_score_row "$(lang_get "cat_io")"               "${DB_SCORE_PG_io:-0}"           "${PG_WEIGHT_IO:-10}"
    _db_score_row "$(lang_get "cat_index_health")"     "${DB_SCORE_PG_indexes:-0}"      "${PG_WEIGHT_INDEXES:-5}"
    _db_score_row "$(lang_get "cat_configuration")"    "${DB_SCORE_PG_config:-0}"       "${PG_WEIGHT_CONFIG:-5}"
    echo ""

    local pg_bar pg_emoji pg_rating
    pg_bar=$(get_rating_bar "${PG_SCORE:-0}")
    pg_emoji=$(get_rating_emoji "${PG_SCORE:-0}")
    pg_rating=$(get_rating_text "${PG_SCORE:-0}")
    echo "**$(lang_get "overall_pg_score")** $pg_emoji $pg_bar **${PG_SCORE:-0}/100** -- $pg_rating"
    echo ""

    # ---- Key Findings ----
    echo "### $(lang_get "db_key_findings")"
    echo ""

    # Cache hit ratio finding
    if (( $(echo "$cache_hit < 95" | bc -l 2>/dev/null || echo 0) )); then
        echo "- **Cache Hit Ratio ($(_fmt_pct "$cache_hit"))** is below the 95% target. Consider increasing \`shared_buffers\` or reviewing query patterns that cause excessive disk reads."
    else
        echo "- **Cache Hit Ratio ($(_fmt_pct "$cache_hit"))** is within the healthy range."
    fi

    # Connection utilization finding
    if (( $(echo "$conn_pct > 75" | bc -l 2>/dev/null || echo 0) )); then
        echo "- **Connection utilization ($(_fmt_pct "$conn_pct"))** is high. Consider implementing connection pooling (PgBouncer) or increasing \`max_connections\`."
    fi

    # Dead tuples finding
    if [ "${dead_int:-0}" -gt 10 ] 2>/dev/null; then
        echo "- **Dead tuple ratio ($(_fmt_pct "$dead_ratio"))** is elevated. Review autovacuum settings — consider lowering \`autovacuum_vacuum_threshold\` and \`autovacuum_vacuum_scale_factor\`."
    fi

    # Deadlocks finding
    if [ "${deadlocks:-0}" -gt 0 ] 2>/dev/null; then
        echo "- **${deadlocks} deadlock(s)** detected. Investigate application transaction patterns and lock ordering."
    fi

    # Index usage finding
    if (( $(echo "$idx_usage < 80" | bc -l 2>/dev/null || echo 0) )); then
        echo "- **Index usage ratio ($(_fmt_pct "$idx_usage"))** is below target. Review query plans with \`EXPLAIN ANALYZE\` and add missing indexes for frequently scanned tables."
    fi

    echo ""

    # ---- What Good Looks Like ----
    lang_get_block "wgll_pg"
    echo ""
    echo "---"
    echo ""
}

# =============================================================================
# 3. report_mongodb() — MongoDB detailed report section
# =============================================================================
report_mongodb() {
    # Guard: skip if not connected
    if [ "${EXTERNAL_MONGO_STATUS:-not_checked}" != "connected" ] || [ -z "$MONGO_RAW_DATA" ]; then
        return
    fi

    echo "## $(lang_get "db_mongo_report")"
    echo ""

    # ---- Connection & Version Info ----
    local mongo_version mongo_host mongo_port
    mongo_version=$(json_val "$MONGO_RAW_DATA" "version" "\"unknown\"")
    mongo_host="${EXTERNAL_MONGO_HOST:-unknown}"
    mongo_port="${EXTERNAL_MONGO_PORT:-27017}"

    echo "### $(lang_get "db_connection_info")"
    echo ""
    echo "| $(lang_get "th_property") | $(lang_get "th_value") |"
    echo "|----------|-------|"
    echo "| **$(lang_get "label_version")** | \`${mongo_version}\` |"
    echo "| **$(lang_get "label_host")** | \`${mongo_host}:${mongo_port}\` |"
    echo "| **$(lang_get "label_engine")** | \`${EXTERNAL_MONGO_ENGINE:-WiredTiger}\` |"
    echo "| **$(lang_get "th_overall_score")** | **${MONGO_SCORE:-0}/100** $(get_rating_emoji "${MONGO_SCORE:-0}") $(get_rating_text "${MONGO_SCORE:-0}") |"
    echo ""

    # ---- Key Metrics Table ----
    local conn_current conn_available read_lat_us read_ops write_lat_us write_ops
    local mem_resident mem_virtual cache_used cache_total repl_set_status
    conn_current=$(json_val "$MONGO_RAW_DATA" "conn_current" "0")
    conn_available=$(json_val "$MONGO_RAW_DATA" "conn_available" "0")
    read_lat_us=$(json_val "$MONGO_RAW_DATA" "read_latency_us" "0")
    read_ops=$(json_val "$MONGO_RAW_DATA" "read_ops" "0")
    write_lat_us=$(json_val "$MONGO_RAW_DATA" "write_latency_us" "0")
    write_ops=$(json_val "$MONGO_RAW_DATA" "write_ops" "0")
    mem_resident=$(json_val "$MONGO_RAW_DATA" "mem_resident" "0")
    mem_virtual=$(json_val "$MONGO_RAW_DATA" "mem_virtual" "0")
    cache_used=$(json_val "$MONGO_RAW_DATA" "cache_bytes_used" "0")
    cache_total=$(json_val "$MONGO_RAW_DATA" "cache_bytes_max" "0")
    local is_replicaset
    is_replicaset=$(json_val "$MONGO_RAW_DATA" "is_replicaset" "false")
    if [ "$is_replicaset" = "true" ]; then
        repl_set_status=$(lang_get "metric_repl_set_status_replica")
    else
        repl_set_status=$(lang_get "metric_repl_set_status_none")
    fi

    # Compute read/write avg latency
    local read_avg_ms="N/A" write_avg_ms="N/A"
    if [ "${read_ops:-0}" -gt 0 ] 2>/dev/null; then
        read_avg_ms=$(echo "scale=2; $read_lat_us / $read_ops / 1000" | bc -l 2>/dev/null || echo "N/A")
        read_avg_ms="${read_avg_ms} ms"
    fi
    if [ "${write_ops:-0}" -gt 0 ] 2>/dev/null; then
        write_avg_ms=$(echo "scale=2; $write_lat_us / $write_ops / 1000" | bc -l 2>/dev/null || echo "N/A")
        write_avg_ms="${write_avg_ms} ms"
    fi

    # Cache utilization
    local cache_pct="N/A"
    if [ "${cache_total:-0}" -gt 0 ] 2>/dev/null; then
        cache_pct=$(echo "scale=1; $cache_used * 100 / $cache_total" | bc -l 2>/dev/null || echo "N/A")
        cache_pct="${cache_pct}%"
    fi

    echo "### $(lang_get "db_key_metrics")"
    echo ""
    echo "| $(lang_get "th_metric") | $(lang_get "th_value") | $(lang_get "th_status") |"
    echo "|--------|-------|--------|"
    echo "| $(lang_get "metric_connections") | ${conn_current}/${conn_available} | $(get_rating_emoji 80) |"
    echo "| $(lang_get "metric_avg_read_latency") | ${read_avg_ms} | |"
    echo "| $(lang_get "metric_avg_write_latency") | ${write_avg_ms} | |"
    echo "| $(lang_get "metric_resident_memory") | ${mem_resident} MB | |"
    echo "| $(lang_get "metric_virtual_memory") | ${mem_virtual} MB | |"
    echo "| $(lang_get "metric_wiredtiger_cache") | ${cache_pct} $(lang_get "label_used") ($(_fmt_bytes "$cache_used") / $(_fmt_bytes "$cache_total")) | |"
    echo "| $(lang_get "metric_replication_status") | ${repl_set_status} | |"
    echo ""

    # ---- Storage Info ----
    local data_size storage_size index_size
    data_size=$(json_val "$MONGO_RAW_DATA" "db_data_size" "0")
    storage_size=$(json_val "$MONGO_RAW_DATA" "db_storage_size" "0")
    index_size=$(json_val "$MONGO_RAW_DATA" "db_index_size" "0")

    if [ "${data_size:-0}" -gt 0 ] 2>/dev/null || [ "${storage_size:-0}" -gt 0 ] 2>/dev/null; then
        echo "### $(lang_get "db_storage")"
        echo ""
        echo "| $(lang_get "th_component") | $(lang_get "th_size") |"
        echo "|-----------|------|"
        echo "| $(lang_get "storage_data_size") | $(_fmt_bytes "$data_size") |"
        echo "| $(lang_get "storage_storage_size") | $(_fmt_bytes "$storage_size") |"
        echo "| $(lang_get "storage_index_size") | $(_fmt_bytes "$index_size") |"

        # Compression ratio
        if [ "${data_size:-0}" -gt 0 ] 2>/dev/null && [ "${storage_size:-0}" -gt 0 ] 2>/dev/null; then
            local compression
            compression=$(echo "scale=2; $data_size / $storage_size" | bc -l 2>/dev/null || echo "N/A")
            echo "| $(lang_get "storage_compression_ratio") | ${compression}:1 |"
        fi
        echo ""
    fi

    # ---- Category Score Breakdown ----
    echo "### $(lang_get "category_scores")"
    echo ""
    echo "| $(lang_get "th_category") | $(lang_get "th_score") | $(lang_get "th_weight") | $(lang_get "th_rating") |"
    echo "|----------|-------|--------|--------|"
    _db_score_row "$(lang_get "cat_performance")"       "${MONGO_SCORE_PERFORMANCE:-0}"  "${MONGO_WEIGHT_PERFORMANCE:-20}"
    _db_score_row "$(lang_get "cat_mongo_replication")" "${MONGO_SCORE_REPLICATION:-0}"  "${MONGO_WEIGHT_REPLICATION:-20}"
    _db_score_row "$(lang_get "cat_mongo_resources")"   "${MONGO_SCORE_RESOURCES:-0}"    "${MONGO_WEIGHT_RESOURCES:-15}"
    _db_score_row "$(lang_get "cat_mongo_storage")"     "${MONGO_SCORE_STORAGE:-0}"      "${MONGO_WEIGHT_STORAGE:-15}"
    _db_score_row "$(lang_get "cat_db_security")"       "${MONGO_SCORE_SECURITY:-0}"     "${MONGO_WEIGHT_SECURITY:-10}"
    _db_score_row "$(lang_get "cat_cluster_topology")"  "${MONGO_SCORE_CLUSTER:-0}"      "${MONGO_WEIGHT_CLUSTER:-10}"
    _db_score_row "$(lang_get "cat_index_health")"      "${MONGO_SCORE_INDEX:-0}"        "${MONGO_WEIGHT_INDEX:-5}"
    _db_score_row "$(lang_get "cat_configuration")"     "${MONGO_SCORE_CONFIG:-0}"       "${MONGO_WEIGHT_CONFIG:-5}"
    echo ""

    local mongo_bar mongo_emoji mongo_rating
    mongo_bar=$(get_rating_bar "${MONGO_SCORE:-0}")
    mongo_emoji=$(get_rating_emoji "${MONGO_SCORE:-0}")
    mongo_rating=$(get_rating_text "${MONGO_SCORE:-0}")
    echo "**$(lang_get "overall_mongo_score")** $mongo_emoji $mongo_bar **${MONGO_SCORE:-0}/100** -- $mongo_rating"
    echo ""

    # ---- Key Findings ----
    echo "### $(lang_get "db_key_findings")"
    echo ""

    if [ "$is_replicaset" != "true" ]; then
        echo "- **No replica set configured.** Running without replication means no automatic failover. Consider deploying a replica set for high availability."
    fi

    if [ "${conn_current:-0}" -gt 0 ] 2>/dev/null && [ "${conn_available:-0}" -gt 0 ] 2>/dev/null; then
        local conn_pct_mongo
        conn_pct_mongo=$(echo "scale=0; $conn_current * 100 / $conn_available" | bc 2>/dev/null || echo "0")
        if [ "${conn_pct_mongo:-0}" -gt 75 ] 2>/dev/null; then
            echo "- **Connection utilization (${conn_pct_mongo}%)** is high. Review connection pool sizes in application drivers."
        fi
    fi

    if [ "${cache_total:-0}" -gt 0 ] 2>/dev/null && [ "${cache_used:-0}" -gt 0 ] 2>/dev/null; then
        local cache_pct_int
        cache_pct_int=$(echo "scale=0; $cache_used * 100 / $cache_total" | bc 2>/dev/null || echo "0")
        if [ "${cache_pct_int:-0}" -gt 95 ] 2>/dev/null; then
            echo "- **WiredTiger cache utilization (${cache_pct_int}%)** is very high. Consider increasing \`wiredTigerCacheSizeGB\` or adding more RAM."
        fi
    fi

    echo ""

    # ---- What Good Looks Like ----
    lang_get_block "wgll_mongo"
    echo ""
    echo "---"
    echo ""
}

# =============================================================================
# 4. report_valkey() — Valkey/Redis detailed report section
# =============================================================================
report_valkey() {
    # Guard: skip if not connected
    if [ "${EXTERNAL_REDIS_STATUS:-not_checked}" != "connected" ] || [ -z "$VALKEY_RAW_DATA" ]; then
        return
    fi

    echo "## $(lang_get "db_valkey_report")"
    echo ""

    # ---- Version & Connection Info ----
    local redis_version uptime_seconds role
    redis_version=$(redis_info_val "redis_version" "unknown")
    uptime_seconds=$(redis_info_val "uptime_in_seconds" "0")
    role=$(redis_info_val "role" "unknown")

    local uptime_days="0"
    if [ "${uptime_seconds:-0}" -gt 0 ] 2>/dev/null; then
        uptime_days=$(echo "scale=1; $uptime_seconds / 86400" | bc -l 2>/dev/null || echo "0")
    fi

    echo "### $(lang_get "db_connection_info")"
    echo ""
    echo "| $(lang_get "th_property") | $(lang_get "th_value") |"
    echo "|----------|-------|"
    echo "| **$(lang_get "label_version")** | \`${redis_version}\` |"
    echo "| **$(lang_get "label_host")** | \`${EXTERNAL_REDIS_HOST:-unknown}:${EXTERNAL_REDIS_PORT:-6379}\` |"
    echo "| **$(lang_get "label_role")** | \`${role}\` |"
    echo "| **$(lang_get "label_uptime")** | ${uptime_days} $(lang_get "label_days") |"
    echo "| **$(lang_get "th_overall_score")** | **${VALKEY_SCORE:-0}/100** $(get_rating_emoji "${VALKEY_SCORE:-0}") $(get_rating_text "${VALKEY_SCORE:-0}") |"
    echo ""

    # ---- Key Metrics Table ----
    local used_memory maxmemory frag_ratio hit_rate connected_clients ops_sec evicted slowlog_len
    used_memory=$(redis_info_val "used_memory" "0")
    maxmemory=$(redis_info_val "maxmemory" "0")
    frag_ratio=$(redis_info_val "mem_fragmentation_ratio" "0")
    local keyspace_hits keyspace_misses
    keyspace_hits=$(redis_info_val "keyspace_hits" "0")
    keyspace_misses=$(redis_info_val "keyspace_misses" "0")
    connected_clients=$(redis_info_val "connected_clients" "0")
    ops_sec=$(redis_info_val "instantaneous_ops_per_sec" "0")
    evicted=$(redis_info_val "evicted_keys" "0")
    slowlog_len="${VALKEY_SLOWLOG_LEN:-0}"

    # Calculate hit ratio
    local total_keyspace hit_ratio_display
    total_keyspace=$(( ${keyspace_hits:-0} + ${keyspace_misses:-0} ))
    hit_ratio_display="N/A"
    if [ "${total_keyspace:-0}" -gt 0 ] 2>/dev/null; then
        hit_ratio_display=$(echo "scale=2; $keyspace_hits * 100 / $total_keyspace" | bc -l 2>/dev/null || echo "N/A")
        hit_ratio_display="${hit_ratio_display}%"
    fi

    # Memory usage display
    local mem_pct_display="N/A"
    if [ "${maxmemory:-0}" -gt 0 ] 2>/dev/null; then
        mem_pct_display=$(echo "scale=1; $used_memory * 100 / $maxmemory" | bc -l 2>/dev/null || echo "N/A")
        mem_pct_display="${mem_pct_display}%"
    fi

    echo "### $(lang_get "db_key_metrics")"
    echo ""
    echo "| $(lang_get "th_metric") | $(lang_get "th_value") | $(lang_get "th_status") |"
    echo "|--------|-------|--------|"

    # Memory usage
    local mem_status="$(get_rating_emoji 80) $(lang_get "status_ok")"
    if [ "${maxmemory:-0}" -gt 0 ] 2>/dev/null; then
        local mem_pct_int
        mem_pct_int=$(echo "scale=0; $used_memory * 100 / $maxmemory" | bc 2>/dev/null || echo "0")
        if [ "${mem_pct_int:-0}" -gt 90 ] 2>/dev/null; then mem_status="$(get_rating_emoji 30) $(lang_get "status_critical")"
        elif [ "${mem_pct_int:-0}" -gt 75 ] 2>/dev/null; then mem_status="$(get_rating_emoji 55) $(lang_get "status_warning")"
        fi
        echo "| $(lang_get "metric_memory_usage") | $(_fmt_bytes "$used_memory") / $(_fmt_bytes "$maxmemory") (${mem_pct_display}) | $mem_status |"
    else
        echo "| $(lang_get "metric_memory_usage") | $(_fmt_bytes "$used_memory") ($(lang_get "status_no_maxmemory")) | $(get_rating_emoji 55) $(lang_get "status_no_limit") |"
    fi

    # Fragmentation ratio
    local frag_status="$(get_rating_emoji 80) $(lang_get "status_ok")"
    if (( $(echo "$frag_ratio > 1.5" | bc -l 2>/dev/null || echo 0) )); then frag_status="$(get_rating_emoji 30) $(lang_get "status_high_frag")"
    elif (( $(echo "$frag_ratio < 1.0" | bc -l 2>/dev/null || echo 0) )); then frag_status="$(get_rating_emoji 55) $(lang_get "status_using_swap")"
    fi
    echo "| $(lang_get "metric_fragmentation_ratio") | ${frag_ratio} | $frag_status |"

    # Hit ratio
    echo "| $(lang_get "metric_hit_ratio") | ${hit_ratio_display} | |"

    # Connected clients
    echo "| $(lang_get "metric_connected_clients") | ${connected_clients} | |"

    # Ops/sec
    echo "| $(lang_get "metric_ops_per_sec") | ${ops_sec} | |"

    # Evicted keys
    local evict_status="$(get_rating_emoji 95) $(lang_get "status_none")"
    if [ "${evicted:-0}" -gt 1000 ] 2>/dev/null; then evict_status="$(get_rating_emoji 30) $(lang_get "status_critical")"
    elif [ "${evicted:-0}" -gt 0 ] 2>/dev/null; then evict_status="$(get_rating_emoji 65) $(lang_get "status_evictions_occurring")"
    fi
    echo "| $(lang_get "metric_evicted_keys") | ${evicted} | $evict_status |"

    # Slowlog entries
    local slow_status="$(get_rating_emoji 95) $(lang_get "status_clean")"
    if [ "${slowlog_len:-0}" -gt 100 ] 2>/dev/null; then slow_status="$(get_rating_emoji 30) $(lang_get "status_many_slow_queries")"
    elif [ "${slowlog_len:-0}" -gt 10 ] 2>/dev/null; then slow_status="$(get_rating_emoji 55) $(lang_get "status_some_slow_queries")"
    elif [ "${slowlog_len:-0}" -gt 0 ] 2>/dev/null; then slow_status="$(get_rating_emoji 65) $(lang_get "status_few_slow_queries")"
    fi
    echo "| $(lang_get "metric_slowlog_entries") | ${slowlog_len} | $slow_status |"

    echo ""

    # ---- Memory Breakdown ----
    local used_memory_rss used_memory_peak used_memory_lua
    used_memory_rss=$(redis_info_val "used_memory_rss" "0")
    used_memory_peak=$(redis_info_val "used_memory_peak" "0")
    used_memory_lua=$(redis_info_val "used_memory_lua" "0")

    echo "### $(lang_get "db_memory_breakdown")"
    echo ""
    echo "| $(lang_get "th_component") | $(lang_get "th_size") |"
    echo "|-----------|------|"
    echo "| $(lang_get "metric_used_memory") | $(_fmt_bytes "$used_memory") |"
    echo "| $(lang_get "metric_rss") | $(_fmt_bytes "$used_memory_rss") |"
    echo "| $(lang_get "metric_peak") | $(_fmt_bytes "$used_memory_peak") |"
    echo "| $(lang_get "metric_lua_engine") | $(_fmt_bytes "$used_memory_lua") |"
    if [ "${maxmemory:-0}" -gt 0 ] 2>/dev/null; then
        echo "| $(lang_get "metric_max_memory_limit") | $(_fmt_bytes "$maxmemory") |"
    fi
    echo "| $(lang_get "metric_eviction_policy") | \`${VALKEY_MAXMEMORY_POLICY:-unknown}\` |"
    echo ""

    # ---- Category Score Breakdown ----
    echo "### $(lang_get "category_scores")"
    echo ""
    echo "| $(lang_get "th_category") | $(lang_get "th_score") | $(lang_get "th_weight") | $(lang_get "th_rating") |"
    echo "|----------|-------|--------|--------|"
    _db_score_row "$(lang_get "cat_memory_mgmt")"        "${VALKEY_SCORE_MEMORY:-0}"       "${VALKEY_WEIGHT_MEMORY:-20}"
    _db_score_row "$(lang_get "cat_performance")"       "${VALKEY_SCORE_PERFORMANCE:-0}"  "${VALKEY_WEIGHT_PERFORMANCE:-20}"
    _db_score_row "$(lang_get "cat_mongo_replication")"  "${VALKEY_SCORE_REPLICATION:-0}"  "${VALKEY_WEIGHT_REPLICATION:-15}"
    _db_score_row "$(lang_get "cat_persistence")"       "${VALKEY_SCORE_PERSISTENCE:-0}"  "${VALKEY_WEIGHT_PERSISTENCE:-15}"
    _db_score_row "$(lang_get "cat_connections")"       "${VALKEY_SCORE_CONNECTIONS:-0}"  "${VALKEY_WEIGHT_CONNECTIONS:-10}"
    _db_score_row "$(lang_get "cat_cluster_health")"    "${VALKEY_SCORE_CLUSTER:-0}"      "${VALKEY_WEIGHT_CLUSTER:-10}"
    _db_score_row "$(lang_get "cat_db_security")"       "${VALKEY_SCORE_SECURITY:-0}"     "${VALKEY_WEIGHT_SECURITY:-5}"
    _db_score_row "$(lang_get "cat_configuration")"     "${VALKEY_SCORE_CONFIG:-0}"       "${VALKEY_WEIGHT_CONFIG:-5}"
    echo ""

    local valkey_bar valkey_emoji valkey_rating
    valkey_bar=$(get_rating_bar "${VALKEY_SCORE:-0}")
    valkey_emoji=$(get_rating_emoji "${VALKEY_SCORE:-0}")
    valkey_rating=$(get_rating_text "${VALKEY_SCORE:-0}")
    echo "**$(lang_get "overall_valkey_score")** $valkey_emoji $valkey_bar **${VALKEY_SCORE:-0}/100** -- $valkey_rating"
    echo ""

    # ---- Key Findings ----
    echo "### $(lang_get "db_key_findings")"
    echo ""

    if [ "${maxmemory:-0}" -eq 0 ] 2>/dev/null; then
        echo "- **No maxmemory limit set.** Without a memory limit, Redis can consume all available memory and trigger OOM kills. Set \`maxmemory\` with an appropriate eviction policy."
    fi

    if (( $(echo "$frag_ratio > 1.5" | bc -l 2>/dev/null || echo 0) )); then
        echo "- **Memory fragmentation ratio (${frag_ratio})** is high. Consider restarting the instance or using \`MEMORY PURGE\` (Redis 4+) to reduce fragmentation."
    fi

    if (( $(echo "$frag_ratio < 1.0" | bc -l 2>/dev/null || echo 0) )) && (( $(echo "$frag_ratio > 0" | bc -l 2>/dev/null || echo 0) )); then
        echo "- **Memory fragmentation ratio (${frag_ratio})** is below 1.0, indicating the OS is swapping Redis memory. This severely impacts performance. Add more RAM or reduce dataset size."
    fi

    if [ "${evicted:-0}" -gt 0 ] 2>/dev/null; then
        echo "- **${evicted} keys evicted.** This means maxmemory was reached and data is being dropped. Review if the dataset size is appropriate or increase maxmemory."
    fi

    if [ "${slowlog_len:-0}" -gt 10 ] 2>/dev/null; then
        echo "- **${slowlog_len} slowlog entries detected.** Review slow commands with \`SLOWLOG GET\`. Common culprits: KEYS, large SORT operations, blocking commands."
    fi

    if [ "$role" = "master" ]; then
        local connected_slaves
        connected_slaves=$(redis_info_val "connected_slaves" "0")
        if [ "${connected_slaves:-0}" -eq 0 ] 2>/dev/null; then
            echo "- **No replicas connected to this master.** Consider adding replicas for read scaling and failover capability."
        fi
    fi

    echo ""

    # ---- What Good Looks Like ----
    lang_get_block "wgll_valkey"
    echo ""
    echo "---"
    echo ""
}

# =============================================================================
# 5. report_rabbitmq() — RabbitMQ detailed report section
# =============================================================================
report_rabbitmq() {
    # Guard: skip if not connected
    if [ "${EXTERNAL_RABBITMQ_STATUS:-not_checked}" != "connected" ] || [ -z "$RMQ_RAW_DATA" ]; then
        return
    fi

    echo "## $(lang_get "db_rmq_report")"
    echo ""

    # ---- Connection & Version Info ----
    local rmq_version cluster_name
    rmq_version=$(json_val "$RMQ_RAW_DATA" "rabbitmq_version" "\"unknown\"")
    cluster_name=$(json_val "$RMQ_RAW_DATA" "cluster_name" "\"unknown\"")

    echo "### $(lang_get "db_connection_info")"
    echo ""
    echo "| $(lang_get "th_property") | $(lang_get "th_value") |"
    echo "|----------|-------|"
    echo "| **$(lang_get "label_version")** | \`${rmq_version}\` |"
    echo "| **$(lang_get "label_cluster_name")** | \`${cluster_name}\` |"
    echo "| **$(lang_get "label_host")** | \`${EXTERNAL_RABBITMQ_HOST:-unknown}:${EXTERNAL_RABBITMQ_PORT:-15672}\` |"
    echo "| **$(lang_get "th_overall_score")** | **${RMQ_SCORE:-0}/100** $(get_rating_emoji "${RMQ_SCORE:-0}") $(get_rating_text "${RMQ_SCORE:-0}") |"
    echo ""

    # ---- Key Metrics Table ----
    local total_queues total_connections total_channels
    local msg_ready msg_unacked msg_total

    if [ "$JQ_AVAILABLE" = "true" ]; then
        total_queues=$(echo "$RMQ_QUEUES_DATA" | jq 'length' 2>/dev/null || echo "0")
        total_connections=$(echo "$RMQ_CONNECTIONS_DATA" | jq 'length' 2>/dev/null || echo "0")
        total_channels=$(echo "$RMQ_CHANNELS_DATA" | jq 'length' 2>/dev/null || echo "0")
    else
        total_queues="0"
        total_connections="0"
        total_channels="0"
    fi

    msg_ready=$(json_val "$RMQ_RAW_DATA" "queue_totals.messages_ready" "0")
    msg_unacked=$(json_val "$RMQ_RAW_DATA" "queue_totals.messages_unacknowledged" "0")
    msg_total=$(json_val "$RMQ_RAW_DATA" "queue_totals.messages" "0")

    echo "### $(lang_get "db_key_metrics")"
    echo ""
    echo "| $(lang_get "th_metric") | $(lang_get "th_value") | $(lang_get "th_status") |"
    echo "|--------|-------|--------|"
    echo "| $(lang_get "metric_total_queues") | ${total_queues} | |"
    echo "| $(lang_get "metric_total_connections") | ${total_connections} | |"
    echo "| $(lang_get "metric_total_channels") | ${total_channels} | |"

    # Messages ready
    local msg_ready_status="$(get_rating_emoji 80) $(lang_get "status_ok")"
    if [ "${msg_ready:-0}" -gt 100000 ] 2>/dev/null; then msg_ready_status="$(get_rating_emoji 30) $(lang_get "status_critical_backlog")"
    elif [ "${msg_ready:-0}" -gt 10000 ] 2>/dev/null; then msg_ready_status="$(get_rating_emoji 55) $(lang_get "status_elevated")"
    fi
    echo "| $(lang_get "metric_messages_ready") | ${msg_ready} | $msg_ready_status |"

    # Messages unacked
    local msg_unack_status="$(get_rating_emoji 80) $(lang_get "status_ok")"
    if [ "${msg_unacked:-0}" -gt 10000 ] 2>/dev/null; then msg_unack_status="$(get_rating_emoji 30) $(lang_get "status_critical")"
    elif [ "${msg_unacked:-0}" -gt 1000 ] 2>/dev/null; then msg_unack_status="$(get_rating_emoji 55) $(lang_get "status_elevated")"
    fi
    echo "| $(lang_get "metric_messages_unacknowledged") | ${msg_unacked} | $msg_unack_status |"

    echo "| $(lang_get "metric_messages_total") | ${msg_total} | |"
    echo ""

    # ---- Node Health ----
    if [ "$JQ_AVAILABLE" = "true" ] && [ -n "$RMQ_NODES_DATA" ] && [ "$RMQ_NODES_DATA" != "[]" ]; then
        local node_count
        node_count=$(echo "$RMQ_NODES_DATA" | jq 'length' 2>/dev/null || echo "0")
        if [ "${node_count:-0}" -gt 0 ] 2>/dev/null; then
            echo "### $(lang_get "db_node_health")"
            echo ""
            echo "| $(lang_get "th_node") | $(lang_get "th_memory_used") | $(lang_get "th_memory_limit") | $(lang_get "th_disk_free") | $(lang_get "th_fd_used_limit") | $(lang_get "th_running") |"
            echo "|------|-----------|--------------|-----------|---------------|---------|"

            local n=0
            while [ "$n" -lt "$node_count" ]; do
                local nname nmem nmem_limit ndisk nfd_used nfd_limit nrunning
                nname=$(echo "$RMQ_NODES_DATA" | jq -r ".[$n].name // \"unknown\"" 2>/dev/null || echo "unknown")
                nmem=$(echo "$RMQ_NODES_DATA" | jq -r ".[$n].mem_used // 0" 2>/dev/null || echo "0")
                nmem_limit=$(echo "$RMQ_NODES_DATA" | jq -r ".[$n].mem_limit // 0" 2>/dev/null || echo "0")
                ndisk=$(echo "$RMQ_NODES_DATA" | jq -r ".[$n].disk_free // 0" 2>/dev/null || echo "0")
                nfd_used=$(echo "$RMQ_NODES_DATA" | jq -r ".[$n].fd_used // 0" 2>/dev/null || echo "0")
                nfd_limit=$(echo "$RMQ_NODES_DATA" | jq -r ".[$n].fd_total // 0" 2>/dev/null || echo "0")
                nrunning=$(echo "$RMQ_NODES_DATA" | jq -r ".[$n].running // false" 2>/dev/null || echo "false")

                local running_display
                running_display=$(lang_get "label_yes")
                if [ "$nrunning" = "false" ]; then running_display="**$(lang_get "label_no")**"; fi

                echo "| \`${nname}\` | $(_fmt_bytes "$nmem") | $(_fmt_bytes "$nmem_limit") | $(_fmt_bytes "$ndisk") | ${nfd_used}/${nfd_limit} | ${running_display} |"
                n=$((n + 1))
            done
            echo ""
        fi
    fi

    # ---- Queue Summary (Top Queues) ----
    if [ "$JQ_AVAILABLE" = "true" ] && [ -n "$RMQ_QUEUES_DATA" ] && [ "$RMQ_QUEUES_DATA" != "[]" ]; then
        local queue_count
        queue_count=$(echo "$RMQ_QUEUES_DATA" | jq 'length' 2>/dev/null || echo "0")
        if [ "${queue_count:-0}" -gt 0 ] 2>/dev/null; then
            echo "### $(lang_get "db_top_queues") ($(lang_get "db_showing_queues") 10 $(lang_get "db_of") ${queue_count})"
            echo ""
            echo "| $(lang_get "th_queue") | $(lang_get "th_messages") | $(lang_get "th_consumers") | $(lang_get "th_state") |"
            echo "|-------|----------|-----------|-------|"

            # Sort by messages descending, take top 10
            local sorted_queues
            sorted_queues=$(echo "$RMQ_QUEUES_DATA" | jq '[sort_by(-.messages // 0)].[0][:10]' 2>/dev/null || echo "[]")
            local sq_count
            sq_count=$(echo "$sorted_queues" | jq 'length' 2>/dev/null || echo "0")

            local q=0
            while [ "$q" -lt "$sq_count" ]; do
                local qname qmsgs qconsumers qstate
                qname=$(echo "$sorted_queues" | jq -r ".[$q].name // \"unknown\"" 2>/dev/null || echo "unknown")
                qmsgs=$(echo "$sorted_queues" | jq -r ".[$q].messages // 0" 2>/dev/null || echo "0")
                qconsumers=$(echo "$sorted_queues" | jq -r ".[$q].consumers // 0" 2>/dev/null || echo "0")
                qstate=$(echo "$sorted_queues" | jq -r ".[$q].state // \"unknown\"" 2>/dev/null || echo "unknown")

                # Truncate long queue names
                if [ ${#qname} -gt 50 ]; then
                    qname="${qname:0:47}..."
                fi

                echo "| \`${qname}\` | ${qmsgs} | ${qconsumers} | ${qstate} |"
                q=$((q + 1))
            done
            echo ""
        fi
    fi

    # ---- Category Score Breakdown ----
    echo "### $(lang_get "category_scores")"
    echo ""
    echo "| $(lang_get "th_category") | $(lang_get "th_score") | $(lang_get "th_weight") | $(lang_get "th_rating") |"
    echo "|----------|-------|--------|--------|"
    _db_score_row "$(lang_get "cat_queue_health")"      "${RMQ_SCORE_QUEUES:-0}"       "${RMQ_WEIGHT_QUEUES:-20}"
    _db_score_row "$(lang_get "cat_message_flow")"     "${RMQ_SCORE_FLOW:-0}"         "${RMQ_WEIGHT_THROUGHPUT:-20}"
    _db_score_row "$(lang_get "cat_node_resources")"   "${RMQ_SCORE_RESOURCES:-0}"    "${RMQ_WEIGHT_RESOURCES:-15}"
    _db_score_row "$(lang_get "cat_cluster_health")"   "${RMQ_SCORE_CLUSTER:-0}"      "${RMQ_WEIGHT_CLUSTER:-15}"
    _db_score_row "$(lang_get "cat_connections")"      "${RMQ_SCORE_CONNECTIONS:-0}"   "${RMQ_WEIGHT_CONNECTIONS:-10}"
    _db_score_row "$(lang_get "cat_db_security")"      "${RMQ_SCORE_SECURITY:-0}"     "${RMQ_WEIGHT_SECURITY:-10}"
    _db_score_row "$(lang_get "cat_persistence")"      "${RMQ_SCORE_PERSISTENCE:-0}"  "${RMQ_WEIGHT_PERSISTENCE:-5}"
    _db_score_row "$(lang_get "cat_configuration")"    "${RMQ_SCORE_CONFIG:-0}"       "${RMQ_WEIGHT_CONFIG:-5}"
    echo ""

    local rmq_bar rmq_emoji rmq_rating
    rmq_bar=$(get_rating_bar "${RMQ_SCORE:-0}")
    rmq_emoji=$(get_rating_emoji "${RMQ_SCORE:-0}")
    rmq_rating=$(get_rating_text "${RMQ_SCORE:-0}")
    echo "**$(lang_get "overall_rmq_score")** $rmq_emoji $rmq_bar **${RMQ_SCORE:-0}/100** -- $rmq_rating"
    echo ""

    # ---- Key Findings ----
    echo "### $(lang_get "db_key_findings")"
    echo ""

    if [ "${msg_ready:-0}" -gt 10000 ] 2>/dev/null; then
        echo "- **${msg_ready} messages ready** in queues. Consumers may be unable to keep up. Check consumer health, increase consumer count, or review prefetch settings."
    fi

    if [ "${msg_unacked:-0}" -gt 1000 ] 2>/dev/null; then
        echo "- **${msg_unacked} unacknowledged messages.** Consumers are holding messages without ACKing. Review consumer logic and consider reducing prefetch count."
    fi

    # Check for queues with no consumers
    if [ "$JQ_AVAILABLE" = "true" ] && [ -n "$RMQ_QUEUES_DATA" ] && [ "$RMQ_QUEUES_DATA" != "[]" ]; then
        local orphan_queues
        orphan_queues=$(echo "$RMQ_QUEUES_DATA" | jq '[.[] | select(.consumers == 0 and .messages > 0)] | length' 2>/dev/null || echo "0")
        if [ "${orphan_queues:-0}" -gt 0 ] 2>/dev/null; then
            echo "- **${orphan_queues} queue(s) with messages but no consumers.** These queues are accumulating messages with no one processing them. Clean up or attach consumers."
        fi
    fi

    # Check node health
    if [ "$JQ_AVAILABLE" = "true" ] && [ -n "$RMQ_NODES_DATA" ] && [ "$RMQ_NODES_DATA" != "[]" ]; then
        local nodes_down
        nodes_down=$(echo "$RMQ_NODES_DATA" | jq '[.[] | select(.running == false)] | length' 2>/dev/null || echo "0")
        if [ "${nodes_down:-0}" -gt 0 ] 2>/dev/null; then
            echo "- **${nodes_down} node(s) not running.** Cluster capacity is reduced. Investigate and restore downed nodes immediately."
        fi
    fi

    # Check for queues with no consumers (latent risk even if empty)
    if [ "$JQ_AVAILABLE" = "true" ] && [ -n "$RMQ_QUEUES_DATA" ] && [ "$RMQ_QUEUES_DATA" != "[]" ]; then
        local consumerless_queues total_queues_rmq
        consumerless_queues=$(echo "$RMQ_QUEUES_DATA" | jq '[.[] | select(.consumers == 0)] | length' 2>/dev/null || echo "0")
        total_queues_rmq=$(echo "$RMQ_QUEUES_DATA" | jq 'length' 2>/dev/null || echo "0")
        if [ "${consumerless_queues:-0}" -gt 0 ] 2>/dev/null && [ "${total_queues_rmq:-0}" -gt 0 ] 2>/dev/null; then
            local consumerless_pct=$(( consumerless_queues * 100 / total_queues_rmq ))
            if [ "$consumerless_pct" -gt 50 ]; then
                echo "- **${consumerless_queues}/${total_queues_rmq} $(lang_get "db_rmq_consumerless")** $(lang_get "db_rmq_consumerless_detail")"
            fi
        fi
    fi

    # Single-node cluster warning
    if [ "${RMQ_SCORE_CLUSTER:-100}" -le 50 ] 2>/dev/null; then
        local rmq_node_count
        rmq_node_count=$(echo "$RMQ_NODES_DATA" | jq 'length' 2>/dev/null || echo "0")
        if [ "${rmq_node_count:-0}" -le 1 ] 2>/dev/null; then
            echo "- **$(lang_get "db_rmq_single_node")** $(lang_get "db_rmq_single_node_detail")"
        fi
    fi

    # Missing TLS warning
    if [ "${RMQ_SCORE_SECURITY:-100}" -lt 60 ] 2>/dev/null; then
        echo "- **$(lang_get "db_rmq_security_low") (${RMQ_SCORE_SECURITY:-0}/100).** $(lang_get "db_rmq_security_detail")"
    fi

    echo ""

    # ---- What Good Looks Like ----
    lang_get_block "wgll_rmq"
    echo ""
    echo "---"
    echo ""
}

# =============================================================================
# 6. report_unified_score() — Grand Unified Infrastructure Score section
# =============================================================================
report_unified_score() {
    echo "## $(lang_get "db_grand_unified")"
    echo ""
    echo "> Weighted composite score across all infrastructure domains. Absent domains"
    echo "> have their weight redistributed among present domains."
    echo ""

    # Build the domain table dynamically based on what's present
    echo "| $(lang_get "th_domain") | $(lang_get "th_score") | $(lang_get "th_weight") | $(lang_get "th_weighted") |"
    echo "|--------|-------|--------|----------|"

    local total_weight=0
    local total_weighted=0

    # Track which domains are present for weight redistribution display
    local present_count=0

    # K8s
    if [ "${K8S_SCORE_OVERALL:-0}" -gt 0 ] 2>/dev/null; then
        present_count=$((present_count + 1))
    fi
    if [ "${EXTERNAL_PG_STATUS:-}" = "connected" ] && [ "${PG_SCORE:-0}" -gt 0 ] 2>/dev/null; then
        present_count=$((present_count + 1))
    fi
    if [ "${EXTERNAL_MONGO_STATUS:-}" = "connected" ] && [ "${MONGO_SCORE:-0}" -gt 0 ] 2>/dev/null; then
        present_count=$((present_count + 1))
    fi
    if [ "${EXTERNAL_REDIS_STATUS:-}" = "connected" ] && [ "${VALKEY_SCORE:-0}" -gt 0 ] 2>/dev/null; then
        present_count=$((present_count + 1))
    fi
    if [ "${EXTERNAL_RABBITMQ_STATUS:-}" = "connected" ] && [ "${RMQ_SCORE:-0}" -gt 0 ] 2>/dev/null; then
        present_count=$((present_count + 1))
    fi

    # Compute effective weights (redistribute among present domains)
    local eff_k8s=0 eff_pg=0 eff_mongo=0 eff_valkey=0 eff_rmq=0

    # Collect raw weights for present domains
    local raw_total=0
    if [ "${K8S_SCORE_OVERALL:-0}" -gt 0 ] 2>/dev/null; then
        raw_total=$((raw_total + ${UNIFIED_WEIGHT_K8S:-30}))
    fi
    if [ "${EXTERNAL_PG_STATUS:-}" = "connected" ] && [ "${PG_SCORE:-0}" -gt 0 ] 2>/dev/null; then
        raw_total=$((raw_total + ${UNIFIED_WEIGHT_PG:-25}))
    fi
    if [ "${EXTERNAL_MONGO_STATUS:-}" = "connected" ] && [ "${MONGO_SCORE:-0}" -gt 0 ] 2>/dev/null; then
        raw_total=$((raw_total + ${UNIFIED_WEIGHT_MONGO:-20}))
    fi
    if [ "${EXTERNAL_REDIS_STATUS:-}" = "connected" ] && [ "${VALKEY_SCORE:-0}" -gt 0 ] 2>/dev/null; then
        raw_total=$((raw_total + ${UNIFIED_WEIGHT_VALKEY:-15}))
    fi
    if [ "${EXTERNAL_RABBITMQ_STATUS:-}" = "connected" ] && [ "${RMQ_SCORE:-0}" -gt 0 ] 2>/dev/null; then
        raw_total=$((raw_total + ${UNIFIED_WEIGHT_RMQ:-10}))
    fi

    # Helper to compute effective weight percentage and weighted score
    _unified_domain_row() {
        local name="$1" score="$2" raw_weight="$3" present="$4"
        if [ "$present" = "true" ] && [ "${raw_total:-0}" -gt 0 ] 2>/dev/null; then
            local eff_weight_pct
            eff_weight_pct=$(echo "scale=1; $raw_weight * 100 / $raw_total" | bc -l 2>/dev/null || echo "0")
            local weighted
            weighted=$(echo "scale=1; $score * $eff_weight_pct / 100" | bc -l 2>/dev/null || echo "0")
            total_weight=$(echo "scale=1; $total_weight + $eff_weight_pct" | bc -l 2>/dev/null || echo "$total_weight")
            total_weighted=$(echo "scale=1; $total_weighted + $weighted" | bc -l 2>/dev/null || echo "$total_weighted")
            echo "| $name | ${score} | ${eff_weight_pct}% | ${weighted} |"
        else
            echo "| $name | - | - | - |"
        fi
    }

    # K8s row
    local k8s_present="false"
    if [ "${K8S_SCORE_OVERALL:-0}" -gt 0 ] 2>/dev/null; then k8s_present="true"; fi
    _unified_domain_row "Kubernetes" "${K8S_SCORE_OVERALL:-0}" "${UNIFIED_WEIGHT_K8S:-30}" "$k8s_present"

    # PG row
    local pg_present="false"
    if [ "${EXTERNAL_PG_STATUS:-}" = "connected" ] && [ "${PG_SCORE:-0}" -gt 0 ] 2>/dev/null; then pg_present="true"; fi
    _unified_domain_row "PostgreSQL" "${PG_SCORE:-0}" "${UNIFIED_WEIGHT_PG:-25}" "$pg_present"

    # Mongo row
    local mongo_present="false"
    if [ "${EXTERNAL_MONGO_STATUS:-}" = "connected" ] && [ "${MONGO_SCORE:-0}" -gt 0 ] 2>/dev/null; then mongo_present="true"; fi
    _unified_domain_row "MongoDB" "${MONGO_SCORE:-0}" "${UNIFIED_WEIGHT_MONGO:-20}" "$mongo_present"

    # Valkey row
    local valkey_present="false"
    if [ "${EXTERNAL_REDIS_STATUS:-}" = "connected" ] && [ "${VALKEY_SCORE:-0}" -gt 0 ] 2>/dev/null; then valkey_present="true"; fi
    _unified_domain_row "Valkey/Redis" "${VALKEY_SCORE:-0}" "${UNIFIED_WEIGHT_VALKEY:-15}" "$valkey_present"

    # RMQ row
    local rmq_present="false"
    if [ "${EXTERNAL_RABBITMQ_STATUS:-}" = "connected" ] && [ "${RMQ_SCORE:-0}" -gt 0 ] 2>/dev/null; then rmq_present="true"; fi
    _unified_domain_row "RabbitMQ" "${RMQ_SCORE:-0}" "${UNIFIED_WEIGHT_RMQ:-10}" "$rmq_present"

    # Grand total row
    local total_weighted_int
    total_weighted_int=$(printf "%.0f" "$total_weighted" 2>/dev/null || echo "0")
    echo "| **$(lang_get "grand_total")** | **${UNIFIED_SCORE:-0}** | **100%** | **${total_weighted}** |"

    echo ""

    # Progress bar
    local unified_bar unified_emoji unified_rating
    unified_bar=$(get_rating_bar "${UNIFIED_SCORE:-0}")
    unified_emoji=$(get_rating_emoji "${UNIFIED_SCORE:-0}")
    unified_rating=$(get_rating_text "${UNIFIED_SCORE:-0}")

    echo "**$(lang_get "grand_unified_label")**"
    echo ""
    echo "$unified_emoji $unified_bar **${UNIFIED_SCORE:-0}/100**"
    echo ""
    echo "**$(lang_get "th_rating"):** $unified_emoji $unified_rating (${UNIFIED_SCORE:-0}/100)"
    echo ""

    # Interpretation guide
    if [ "${UNIFIED_SCORE:-0}" -ge 90 ] 2>/dev/null; then
        echo "> **$(lang_get "rating_excellent")** -- $(lang_get "unified_excellent")"
    elif [ "${UNIFIED_SCORE:-0}" -ge 75 ] 2>/dev/null; then
        echo "> **$(lang_get "rating_good")** -- $(lang_get "unified_good")"
    elif [ "${UNIFIED_SCORE:-0}" -ge 60 ] 2>/dev/null; then
        echo "> **$(lang_get "rating_fair")** -- $(lang_get "unified_fair")"
    elif [ "${UNIFIED_SCORE:-0}" -ge 40 ] 2>/dev/null; then
        echo "> **$(lang_get "rating_poor")** -- $(lang_get "unified_poor")"
    else
        echo "> **$(lang_get "rating_critical")** -- $(lang_get "unified_critical")"
    fi

    echo ""
    echo "---"
    echo ""
}
