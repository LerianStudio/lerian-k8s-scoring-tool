#!/bin/bash
# =============================================================================
# 04_collect_pg.sh - PostgreSQL Data Collection
# =============================================================================
# Connects to PostgreSQL and collects comprehensive metrics for scoring.
# Uses multi-round retry with host/port/SSL mode permutations.
#
# Populates: PG_RAW_DATA, PG_BGWRITER_DATA, PG_TABLE_IO_DATA,
#            PG_INDEX_IO_DATA, PG_WAL_IO_DATA, PG_STAT_IO_DATA,
#            PG_TABLES_DATA, PG_INDEXES_DATA, PG_DATABASES_DATA,
#            PG_SEQ_SCANS_DATA, PG_DUPLICATE_INDEXES, PG_ROLES_DATA,
#            PG_CONNECTIONS_DATA, PG_REPL_SLOTS
#
# Compatibility: Bash 3.2+ (no associative arrays, no namerefs)
# =============================================================================

# -----------------------------------------------------------------------------
# try_psql_connect - Test a PostgreSQL connection
# Arguments: host, port, user, sslmode (optional)
# Returns: 0 on success, 1 on failure
# -----------------------------------------------------------------------------
try_psql_connect() {
    local host="$1"
    local port="$2"
    local user="$3"
    local sslmode="$4"

    if [ -n "$sslmode" ]; then
        export PGSSLMODE="$sslmode"
    fi

    PGCONNECT_TIMEOUT=5 psql -w -h "$host" -p "$port" -U "$user" -d postgres -c "SELECT 1" >/dev/null 2>&1
    local rc=$?

    if [ -n "$sslmode" ]; then
        unset PGSSLMODE
    fi

    return $rc
}

# -----------------------------------------------------------------------------
# collect_postgresql_data - Main PostgreSQL data collection function
# Requires: PSQL_AVAILABLE, EXTERNAL_PG_HOST, EXTERNAL_PG_PORT,
#           EXTERNAL_PG_USER, EXTERNAL_PG_PASS, EXTERNAL_PG_DATABASES
# -----------------------------------------------------------------------------
collect_postgresql_data() {
    log_info "Collecting PostgreSQL data..."

    # --- Guard: psql must be available ---
    if [ "$PSQL_AVAILABLE" != "true" ]; then
        log_warning "psql not available - skipping PostgreSQL collection"
        attention_add "PostgreSQL" "WARNING" "psql client not available — PostgreSQL collection skipped. Install postgresql-client to enable."
        EXTERNAL_PG_STATUS="skipped"
        return
    fi

    # --- Guard: credentials must be present ---
    if [ -z "$EXTERNAL_PG_HOST" ] || [ -z "$EXTERNAL_PG_USER" ]; then
        log_warning "PostgreSQL host or user not configured - skipping"
        attention_add "PostgreSQL" "WARNING" "PostgreSQL host or user not configured — collection skipped. Set EXTERNAL_PG_HOST and EXTERNAL_PG_USER."
        EXTERNAL_PG_STATUS="skipped"
        return
    fi

    local pg_port="${EXTERNAL_PG_PORT:-5432}"

    # Export password for all psql calls
    export PGPASSWORD="$EXTERNAL_PG_PASS"

    # --- Resolve host for local environments ---
    local resolved_host
    resolved_host=$(resolve_host_for_local "$EXTERNAL_PG_HOST")
    log_info "PostgreSQL host resolved: $EXTERNAL_PG_HOST -> $resolved_host"

    # --- Build host/port candidate list ---
    local host_list
    host_list=$(build_connection_hosts "$EXTERNAL_PG_HOST" "$resolved_host")
    log_info "PostgreSQL candidate hosts: $host_list"

    local port_list="$pg_port"
    if [ "$pg_port" != "5432" ]; then
        port_list="$pg_port 5432"
    fi

    # --- 3-round retry: try all host/port/ssl combinations ---
    local connected=false
    local conn_host=""
    local conn_port=""
    local ssl_modes="default require disable"
    local round=0

    for ssl in $ssl_modes; do
        round=$((round + 1))
        log_info "PostgreSQL connection attempt round $round (ssl=$ssl)..."

        for h in $host_list; do
            for p in $port_list; do
                local sslarg=""
                if [ "$ssl" != "default" ]; then
                    sslarg="$ssl"
                fi

                if try_psql_connect "$h" "$p" "$EXTERNAL_PG_USER" "$sslarg"; then
                    connected=true
                    conn_host="$h"
                    conn_port="$p"
                    if [ -n "$sslarg" ]; then
                        export PGSSLMODE="$sslarg"
                    fi
                    log_success "PostgreSQL connected: $h:$p (ssl=$ssl)"
                    break 3
                fi
            done
        done
    done

    if [ "$connected" != "true" ]; then
        log_warning "Could not connect to PostgreSQL on any host/port/ssl combination"
        attention_add "PostgreSQL" "ERROR" "Unable to connect to PostgreSQL at ${EXTERNAL_PG_HOST:-unknown}:${pg_port} — all host/port/SSL combinations failed. Check connection credentials and network access."
        EXTERNAL_PG_STATUS="unreachable"
        unset PGPASSWORD
        unset PGSSLMODE
        unset PGCONNECT_TIMEOUT
        return
    fi

    # --- Select database to query ---
    local target_db=""
    if [ -n "$EXTERNAL_PG_DATABASES" ]; then
        local IFS_BAK="$IFS"
        IFS=','
        for db in $EXTERNAL_PG_DATABASES; do
            db=$(echo "$db" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [ -z "$db" ]; then continue; fi
            if PGCONNECT_TIMEOUT=5 psql -w -h "$conn_host" -p "$conn_port" -U "$EXTERNAL_PG_USER" -d "$db" -c "SELECT 1" >/dev/null 2>&1; then
                target_db="$db"
                break
            fi
        done
        IFS="$IFS_BAK"
    fi

    if [ -z "$target_db" ]; then
        target_db="postgres"
        log_info "Using fallback database: postgres"
    else
        log_info "Using database: $target_db"
    fi

    # Common psql flags
    local psql_cmd="PGCONNECT_TIMEOUT=10 psql -w -h $conn_host -p $conn_port -U $EXTERNAL_PG_USER -d $target_db -t -A"

    # =========================================================================
    # Main query: collect ~50 metrics via json_build_object
    # =========================================================================
    local pg_sql=""
    pg_sql="SELECT json_build_object("
    pg_sql="$pg_sql 'database', current_database(),"
    pg_sql="$pg_sql 'server_version', version(),"
    pg_sql="$pg_sql 'cache_hit_ratio', (SELECT CASE WHEN sum(heap_blks_hit) + sum(heap_blks_read) = 0 THEN 100 ELSE round(sum(heap_blks_hit)::numeric / (sum(heap_blks_hit) + sum(heap_blks_read)) * 100, 2) END FROM pg_statio_user_tables),"
    pg_sql="$pg_sql 'index_usage_ratio', (SELECT CASE WHEN sum(seq_scan) + sum(idx_scan) = 0 THEN 100 ELSE round(sum(idx_scan)::numeric / (sum(seq_scan) + sum(idx_scan)) * 100, 2) END FROM pg_stat_user_tables),"
    pg_sql="$pg_sql 'connection_count', (SELECT count(*) FROM pg_stat_activity),"
    pg_sql="$pg_sql 'max_connections', (SELECT setting::int FROM pg_settings WHERE name = 'max_connections'),"
    pg_sql="$pg_sql 'idle_connections', (SELECT count(*) FROM pg_stat_activity WHERE state = 'idle'),"
    pg_sql="$pg_sql 'idle_in_transaction', (SELECT count(*) FROM pg_stat_activity WHERE state = 'idle in transaction'),"
    pg_sql="$pg_sql 'long_running_queries', (SELECT count(*) FROM pg_stat_activity WHERE state = 'active' AND now() - query_start > interval '5 minutes'),"
    pg_sql="$pg_sql 'deadlocks', (SELECT sum(deadlocks) FROM pg_stat_database),"
    pg_sql="$pg_sql 'temp_bytes', (SELECT sum(temp_bytes) FROM pg_stat_database),"
    pg_sql="$pg_sql 'avg_dead_tuple_ratio', (SELECT CASE WHEN count(*) = 0 THEN 0 ELSE round(avg(CASE WHEN n_live_tup + n_dead_tup = 0 THEN 0 ELSE n_dead_tup::numeric / (n_live_tup + n_dead_tup) * 100 END), 2) END FROM pg_stat_user_tables WHERE n_live_tup > 1000),"
    pg_sql="$pg_sql 'xid_age_pct', (SELECT round(max(age(datfrozenxid))::numeric / 2146483647 * 100, 2) FROM pg_database),"
    pg_sql="$pg_sql 'is_replica', pg_is_in_recovery(),"
    pg_sql="$pg_sql 'replication_lag_bytes', (SELECT COALESCE(max(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)), 0) FROM pg_stat_replication),"
    pg_sql="$pg_sql 'replication_count', (SELECT count(*) FROM pg_stat_replication),"
    pg_sql="$pg_sql 'database_size_bytes', pg_database_size(current_database()),"
    pg_sql="$pg_sql 'unused_indexes', (SELECT count(*) FROM pg_stat_user_indexes WHERE idx_scan < 50 AND pg_relation_size(indexrelid) > 81920),"
    pg_sql="$pg_sql 'invalid_indexes', (SELECT count(*) FROM pg_index WHERE NOT indisvalid),"
    pg_sql="$pg_sql 'ssl_connections', (SELECT count(*) FROM pg_stat_ssl WHERE ssl = true),"
    pg_sql="$pg_sql 'total_connections_ssl', (SELECT count(*) FROM pg_stat_ssl),"
    pg_sql="$pg_sql 'superuser_count', (SELECT count(*) FROM pg_roles WHERE rolsuper = true),"
    pg_sql="$pg_sql 'tables_count', (SELECT count(*) FROM pg_stat_user_tables),"
    pg_sql="$pg_sql 'shared_buffers', (SELECT setting FROM pg_settings WHERE name = 'shared_buffers'),"
    pg_sql="$pg_sql 'effective_cache_size', (SELECT setting FROM pg_settings WHERE name = 'effective_cache_size'),"
    pg_sql="$pg_sql 'work_mem', (SELECT setting FROM pg_settings WHERE name = 'work_mem'),"
    pg_sql="$pg_sql 'checkpoint_completion_target', (SELECT setting FROM pg_settings WHERE name = 'checkpoint_completion_target'),"
    pg_sql="$pg_sql 'all_databases_size_bytes', (SELECT sum(pg_database_size(datname)) FROM pg_database WHERE NOT datistemplate),"
    pg_sql="$pg_sql 'wal_size_bytes', 0,"
    pg_sql="$pg_sql 'wal_file_count', 0,"
    pg_sql="$pg_sql 'total_heap_size_bytes', (SELECT COALESCE(sum(pg_relation_size(relid)), 0) FROM pg_stat_user_tables),"
    pg_sql="$pg_sql 'total_index_size_bytes', (SELECT COALESCE(sum(pg_indexes_size(relid)), 0) FROM pg_stat_user_tables),"
    pg_sql="$pg_sql 'total_toast_size_bytes', (SELECT COALESCE(sum(pg_total_relation_size(relid) - pg_relation_size(relid) - pg_indexes_size(relid)), 0) FROM pg_stat_user_tables),"
    pg_sql="$pg_sql 'total_relation_size_bytes', (SELECT COALESCE(sum(pg_total_relation_size(relid)), 0) FROM pg_stat_user_tables),"
    pg_sql="$pg_sql 'total_live_rows', (SELECT COALESCE(sum(n_live_tup), 0) FROM pg_stat_user_tables),"
    pg_sql="$pg_sql 'total_dead_rows', (SELECT COALESCE(sum(n_dead_tup), 0) FROM pg_stat_user_tables),"
    pg_sql="$pg_sql 'estimated_bloat_bytes', (SELECT COALESCE(sum(CASE WHEN n_live_tup > 0 THEN pg_relation_size(relid) * n_dead_tup / (n_live_tup + n_dead_tup) ELSE 0 END), 0) FROM pg_stat_user_tables),"
    pg_sql="$pg_sql 'data_directory', 'N/A',"
    pg_sql="$pg_sql 'tablespace_count', (SELECT count(*) FROM pg_tablespace),"
    pg_sql="$pg_sql 'top_tables', (SELECT COALESCE(json_agg(t), '[]'::json) FROM (SELECT relname AS table_name, pg_total_relation_size(relid) AS total_size_bytes, CASE WHEN n_live_tup + n_dead_tup = 0 THEN 0 ELSE round(n_dead_tup::numeric / (n_live_tup + n_dead_tup) * 100, 2) END AS dead_tuple_ratio FROM pg_stat_user_tables ORDER BY pg_total_relation_size(relid) DESC LIMIT 5) t),"
    pg_sql="$pg_sql 'temp_files', (SELECT sum(temp_files) FROM pg_stat_database),"
    pg_sql="$pg_sql 'checkpoints_timed', 0,"
    pg_sql="$pg_sql 'checkpoints_req', 0,"
    pg_sql="$pg_sql 'buffers_backend_pct', 0,"
    pg_sql="$pg_sql 'track_io_timing', (SELECT setting FROM pg_settings WHERE name = 'track_io_timing'),"
    pg_sql="$pg_sql 'blks_read', (SELECT sum(blks_read) FROM pg_stat_database),"
    pg_sql="$pg_sql 'blks_hit', (SELECT sum(blks_hit) FROM pg_stat_database),"
    pg_sql="$pg_sql 'blk_read_time', (SELECT sum(blk_read_time) FROM pg_stat_database),"
    pg_sql="$pg_sql 'blk_write_time', (SELECT sum(blk_write_time) FROM pg_stat_database)"
    pg_sql="$pg_sql )::text;"

    log_info "Executing main PostgreSQL metrics query..."
    PG_RAW_DATA=$(eval "$psql_cmd" <<< "$pg_sql" 2>/dev/null || echo "")

    if [ -z "$PG_RAW_DATA" ]; then
        log_warning "Main PostgreSQL query returned empty - check permissions"
        attention_add "PostgreSQL" "ERROR" "Unable to collect PostgreSQL metrics from ${conn_host}:${conn_port} — main query returned empty. Check connection credentials and query permissions."
        EXTERNAL_PG_STATUS="error"
        unset PGPASSWORD
        unset PGSSLMODE
        unset PGCONNECT_TIMEOUT
        return
    fi

    log_success "PostgreSQL main metrics collected"
    EXTERNAL_PG_STATUS="connected"

    # =========================================================================
    # Supplementary queries (each tolerant of permission errors)
    # =========================================================================

    # --- WAL info from pg_ls_waldir() ---
    log_info "Collecting PostgreSQL WAL directory info..."
    local wal_info
    wal_info=$(eval "$psql_cmd" -c "SELECT json_build_object('wal_size_bytes', COALESCE(sum(size), 0), 'wal_file_count', count(*)) FROM pg_ls_waldir();" 2>/dev/null || echo "")
    if [ -z "$wal_info" ] || [ "$wal_info" = "" ]; then
        attention_add "PostgreSQL" "WARNING" "WAL directory info (pg_ls_waldir) unavailable — insufficient permissions or PG version < 10. WAL metrics will use defaults."
    fi
    if [ -n "$wal_info" ] && [ "$wal_info" != "" ]; then
        # Patch the WAL placeholders into PG_RAW_DATA
        if [ "$JQ_AVAILABLE" = "true" ]; then
            local wal_size
            local wal_count
            wal_size=$(echo "$wal_info" | jq -r '.wal_size_bytes // 0' 2>/dev/null || echo "0")
            wal_count=$(echo "$wal_info" | jq -r '.wal_file_count // 0' 2>/dev/null || echo "0")
            PG_RAW_DATA=$(echo "$PG_RAW_DATA" | jq --argjson ws "$wal_size" --argjson wc "$wal_count" '.wal_size_bytes = $ws | .wal_file_count = $wc' 2>/dev/null || echo "$PG_RAW_DATA")
        fi
    fi

    # --- Checkpoint stats (PG17 pg_stat_checkpointer or older pg_stat_bgwriter) ---
    log_info "Collecting PostgreSQL checkpoint stats..."
    local ckpt_data
    ckpt_data=$(eval "$psql_cmd" -c "SELECT json_build_object('checkpoints_timed', num_timed, 'checkpoints_req', num_requested) FROM pg_stat_checkpointer;" 2>/dev/null || echo "")
    if [ -z "$ckpt_data" ] || [ "$ckpt_data" = "" ]; then
        ckpt_data=$(eval "$psql_cmd" -c "SELECT json_build_object('checkpoints_timed', checkpoints_timed, 'checkpoints_req', checkpoints_req, 'buffers_backend_pct', CASE WHEN buffers_alloc = 0 THEN 0 ELSE round(buffers_backend::numeric / buffers_alloc * 100, 2) END) FROM pg_stat_bgwriter;" 2>/dev/null || echo "")
    fi
    if [ -n "$ckpt_data" ] && [ "$JQ_AVAILABLE" = "true" ]; then
        local ct cr bbp
        ct=$(echo "$ckpt_data" | jq -r '.checkpoints_timed // 0' 2>/dev/null || echo "0")
        cr=$(echo "$ckpt_data" | jq -r '.checkpoints_req // 0' 2>/dev/null || echo "0")
        bbp=$(echo "$ckpt_data" | jq -r '.buffers_backend_pct // 0' 2>/dev/null || echo "0")
        PG_RAW_DATA=$(echo "$PG_RAW_DATA" | jq --argjson ct "$ct" --argjson cr "$cr" --argjson bbp "$bbp" '.checkpoints_timed = $ct | .checkpoints_req = $cr | .buffers_backend_pct = $bbp' 2>/dev/null || echo "$PG_RAW_DATA")
    fi

    # --- bgwriter buffer data for I/O scoring ---
    log_info "Collecting PostgreSQL bgwriter data..."
    PG_BGWRITER_DATA=$(eval "$psql_cmd" -c "SELECT row_to_json(pg_stat_bgwriter) FROM pg_stat_bgwriter;" 2>/dev/null || echo "")

    # --- Per-table I/O from pg_statio_user_tables ---
    log_info "Collecting PostgreSQL per-table I/O data..."
    PG_TABLE_IO_DATA=$(eval "$psql_cmd" -c "SELECT COALESCE(json_agg(row_to_json(t)), '[]') FROM (SELECT schemaname, relname, heap_blks_read, heap_blks_hit, idx_blks_read, idx_blks_hit, toast_blks_read, toast_blks_hit FROM pg_statio_user_tables ORDER BY heap_blks_read DESC LIMIT 50) t;" 2>/dev/null || echo "[]")

    # --- Per-index I/O from pg_statio_user_indexes ---
    log_info "Collecting PostgreSQL per-index I/O data..."
    PG_INDEX_IO_DATA=$(eval "$psql_cmd" -c "SELECT COALESCE(json_agg(row_to_json(t)), '[]') FROM (SELECT schemaname, relname, indexrelname, idx_blks_read, idx_blks_hit FROM pg_statio_user_indexes ORDER BY idx_blks_read DESC LIMIT 50) t;" 2>/dev/null || echo "[]")

    # --- WAL I/O from pg_stat_wal (PG14+) ---
    log_info "Collecting PostgreSQL WAL I/O stats..."
    PG_WAL_IO_DATA=$(eval "$psql_cmd" -c "SELECT row_to_json(t) FROM (SELECT wal_records, wal_fpi, wal_bytes, wal_buffers_full, wal_write, wal_sync, wal_write_time, wal_sync_time FROM pg_stat_wal) t;" 2>/dev/null || echo "{}")

    # --- pg_stat_io (PG16+) ---
    log_info "Collecting PostgreSQL pg_stat_io data..."
    PG_STAT_IO_DATA=$(eval "$psql_cmd" -c "SELECT COALESCE(json_agg(row_to_json(t)), '[]') FROM (SELECT backend_type, object, context, reads, read_time, writes, write_time, writebacks, writeback_time, extends, extend_time, hits, evictions FROM pg_stat_io) t;" 2>/dev/null || echo "[]")

    # --- All tables with sizes and stats ---
    log_info "Collecting PostgreSQL tables data..."
    PG_TABLES_DATA=$(eval "$psql_cmd" -c "SELECT COALESCE(json_agg(row_to_json(t)), '[]') FROM (SELECT schemaname, relname, pg_total_relation_size(relid) AS total_size_bytes, pg_relation_size(relid) AS table_size_bytes, pg_indexes_size(relid) AS indexes_size_bytes, n_live_tup, n_dead_tup, n_tup_ins, n_tup_upd, n_tup_del, seq_scan, idx_scan, last_vacuum, last_autovacuum, last_analyze, last_autoanalyze FROM pg_stat_user_tables ORDER BY pg_total_relation_size(relid) DESC LIMIT 100) t;" 2>/dev/null || echo "[]")

    # --- All indexes with usage and health ---
    log_info "Collecting PostgreSQL indexes data..."
    PG_INDEXES_DATA=$(eval "$psql_cmd" -c "SELECT COALESCE(json_agg(row_to_json(t)), '[]') FROM (SELECT schemaname, relname, indexrelname, idx_scan, idx_tup_read, idx_tup_fetch, pg_relation_size(indexrelid) AS index_size_bytes FROM pg_stat_user_indexes ORDER BY pg_relation_size(indexrelid) DESC LIMIT 100) t;" 2>/dev/null || echo "[]")

    # --- Per-database sizes ---
    log_info "Collecting PostgreSQL per-database sizes..."
    PG_DATABASES_DATA=$(eval "$psql_cmd" -c "SELECT COALESCE(json_agg(row_to_json(t)), '[]') FROM (SELECT datname, pg_database_size(datname) AS size_bytes, numbackends, xact_commit, xact_rollback, blks_read, blks_hit, tup_returned, tup_fetched, tup_inserted, tup_updated, tup_deleted, deadlocks, temp_files, temp_bytes FROM pg_stat_database WHERE NOT datistemplate AND datname != 'template0' ORDER BY pg_database_size(datname) DESC) t;" 2>/dev/null || echo "[]")

    # --- Tables with high seq scans ---
    log_info "Collecting PostgreSQL high sequential scan tables..."
    PG_SEQ_SCANS_DATA=$(eval "$psql_cmd" -c "SELECT COALESCE(json_agg(row_to_json(t)), '[]') FROM (SELECT schemaname, relname, seq_scan, seq_tup_read, idx_scan, n_live_tup, pg_relation_size(relid) AS table_size_bytes FROM pg_stat_user_tables WHERE seq_scan > 100 AND n_live_tup > 1000 ORDER BY seq_scan DESC LIMIT 20) t;" 2>/dev/null || echo "[]")

    # --- Duplicate/redundant indexes ---
    log_info "Collecting PostgreSQL duplicate indexes..."
    PG_DUPLICATE_INDEXES=$(eval "$psql_cmd" -c "SELECT COALESCE(json_agg(row_to_json(t)), '[]') FROM (SELECT pg_size_pretty(sum(pg_relation_size(idx))::bigint) AS size, string_agg(idx::regclass::text, ', ') AS indexes, (array_agg(idx))[1] AS idx1, (array_agg(idx))[2] AS idx2 FROM (SELECT indexrelid::regclass AS idx, indrelid, indkey, indclass, indoption, (indexprs IS NOT NULL) AS has_exprs, (indpred IS NOT NULL) AS has_pred FROM pg_index) sub GROUP BY indrelid, indkey, indclass, indoption, has_exprs, has_pred HAVING count(*) > 1) t;" 2>/dev/null || echo "[]")

    # --- Roles and permissions ---
    log_info "Collecting PostgreSQL roles data..."
    PG_ROLES_DATA=$(eval "$psql_cmd" -c "SELECT COALESCE(json_agg(row_to_json(t)), '[]') FROM (SELECT rolname, rolsuper, rolinherit, rolcreaterole, rolcreatedb, rolcanlogin, rolreplication, rolconnlimit, rolvaliduntil FROM pg_roles ORDER BY rolname) t;" 2>/dev/null || echo "[]")

    # --- Active connections detail ---
    log_info "Collecting PostgreSQL active connections..."
    PG_CONNECTIONS_DATA=$(eval "$psql_cmd" -c "SELECT COALESCE(json_agg(row_to_json(t)), '[]') FROM (SELECT datname, usename, application_name, client_addr, state, backend_start, query_start, wait_event_type, wait_event FROM pg_stat_activity WHERE pid != pg_backend_pid() ORDER BY backend_start DESC LIMIT 50) t;" 2>/dev/null || echo "[]")

    # --- Replication slots ---
    log_info "Collecting PostgreSQL replication slots..."
    PG_REPL_SLOTS=$(eval "$psql_cmd" -c "SELECT COALESCE(json_agg(row_to_json(t)), '[]') FROM (SELECT slot_name, plugin, slot_type, active, restart_lsn, confirmed_flush_lsn FROM pg_replication_slots) t;" 2>/dev/null || echo "[]")

    # =========================================================================
    # Cleanup
    # =========================================================================
    unset PGPASSWORD
    unset PGSSLMODE
    unset PGCONNECT_TIMEOUT

    log_success "PostgreSQL data collection completed"
}
