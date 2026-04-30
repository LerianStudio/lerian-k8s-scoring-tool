#!/bin/bash
# =============================================================================
# 06_collect_valkey.sh - Valkey / Redis Data Collection
# =============================================================================
# Connects to Valkey/Redis and collects metrics for scoring.
# Uses multi-round retry with host/port/TLS permutations.
#
# Populates: VALKEY_RAW_DATA, VALKEY_SLOWLOG_DATA, VALKEY_SLOWLOG_LEN,
#            VALKEY_CLIENT_LIST, VALKEY_DBSIZE, VALKEY_MAXMEMORY_POLICY,
#            VALKEY_TIMEOUT, VALKEY_HZ, VALKEY_SLOWLOG_THRESHOLD
#
# Compatibility: Bash 3.2+ (no associative arrays, no namerefs)
# =============================================================================

collect_valkey_data() {
    if [ "$REDIS_CLI_AVAILABLE" != "true" ]; then
        attention_add "Valkey" "WARNING" "redis-cli client not available — Valkey/Redis collection skipped. Install redis-tools to enable."
        EXTERNAL_REDIS_STATUS="client_not_available"
        return 0
    fi
    if [ -z "$EXTERNAL_REDIS_HOST" ]; then
        log_warning "Valkey/Redis: Missing connection info (host not configured)"
        attention_add "Valkey" "WARNING" "Valkey/Redis host not configured — collection skipped. Set EXTERNAL_REDIS_HOST."
        EXTERNAL_REDIS_STATUS="not_configured"
        return 0
    fi

    local RESOLVED_REDIS_HOST
    RESOLVED_REDIS_HOST=$(resolve_host_for_local "$EXTERNAL_REDIS_HOST")

    local REDIS_AUTH_ARGS=()
    if [ -n "$EXTERNAL_REDIS_PASS" ]; then
        REDIS_AUTH_ARGS=(-a "$EXTERNAL_REDIS_PASS" --no-auth-warning)
    fi

    local REDIS_CONNECTED=false
    local REDIS_USE_TLS=false

    local HOSTS_TO_TRY
    read -ra HOSTS_TO_TRY <<< "$(build_connection_hosts "$EXTERNAL_REDIS_HOST" "$RESOLVED_REDIS_HOST")"

    local PORTS_TO_TRY=("$EXTERNAL_REDIS_PORT")
    [ "$EXTERNAL_REDIS_PORT" != "6379" ] && PORTS_TO_TRY+=("6379")

    log_info "Valkey/Redis: Attempting connection (hosts: ${HOSTS_TO_TRY[*]}, ports: ${PORTS_TO_TRY[*]})"

    local round_delay=2
    for (( round=1; round<=3; round++ )); do
        if [ $round -gt 1 ]; then
            log_info "Valkey/Redis: Retry round $round/3 (waiting ${round_delay}s)..."
            sleep "$round_delay"
            round_delay=$((round_delay * 2))
        fi
        for try_host in "${HOSTS_TO_TRY[@]}"; do
            for try_port in "${PORTS_TO_TRY[@]}"; do
                if redis-cli $REDIS_TIMEOUT_FLAG 5 -h "$try_host" -p "$try_port" "${REDIS_AUTH_ARGS[@]}" PING 2>/dev/null | grep -q "PONG"; then
                    RESOLVED_REDIS_HOST="$try_host"
                    EXTERNAL_REDIS_PORT="$try_port"
                    REDIS_USE_TLS=false
                    REDIS_CONNECTED=true
                    break 3
                fi
                if redis-cli $REDIS_TIMEOUT_FLAG 5 -h "$try_host" -p "$try_port" "${REDIS_AUTH_ARGS[@]}" --tls --insecure PING 2>/dev/null | grep -q "PONG"; then
                    RESOLVED_REDIS_HOST="$try_host"
                    EXTERNAL_REDIS_PORT="$try_port"
                    REDIS_USE_TLS=true
                    REDIS_CONNECTED=true
                    break 3
                fi
            done
        done
    done

    if [ "$REDIS_CONNECTED" != "true" ]; then
        log_warning "Valkey/Redis: All connection attempts failed after 3 rounds"
        log_warning "  Hosts tried: ${HOSTS_TO_TRY[*]}"
        log_warning "  Ports tried: ${PORTS_TO_TRY[*]}"
        log_warning "  TLS modes tried: off, on"
        attention_add "Valkey" "ERROR" "Unable to connect to Valkey/Redis at ${EXTERNAL_REDIS_HOST:-unknown}:${EXTERNAL_REDIS_PORT:-6379} — all host/port/TLS combinations failed after 3 rounds. Check connection credentials and network access."
        EXTERNAL_REDIS_STATUS="connection_failed"
        return 0
    fi

    local tls_label="off"
    [ "$REDIS_USE_TLS" = "true" ] && tls_label="on"
    log_success "Valkey/Redis: Connected to $RESOLVED_REDIS_HOST:$EXTERNAL_REDIS_PORT (tls=$tls_label)"
    EXTERNAL_REDIS_STATUS="connected"

    local -a RCLI=(redis-cli $REDIS_TIMEOUT_FLAG 5 -h "$RESOLVED_REDIS_HOST" -p "$EXTERNAL_REDIS_PORT" "${REDIS_AUTH_ARGS[@]}")
    if [ "$REDIS_USE_TLS" = "true" ]; then
        RCLI+=(--tls --insecure)
    fi

    VALKEY_RAW_DATA=$("${RCLI[@]}" INFO 2>/dev/null || echo "")
    if [ -z "$VALKEY_RAW_DATA" ]; then
        attention_add "Valkey" "ERROR" "Valkey/Redis INFO command returned empty from ${RESOLVED_REDIS_HOST}:${EXTERNAL_REDIS_PORT} — connected but unable to retrieve metrics. Check AUTH permissions."
        EXTERNAL_REDIS_STATUS="error"
        return 0
    fi
    VALKEY_SLOWLOG_DATA=$("${RCLI[@]}" SLOWLOG GET 10 2>/dev/null || echo "")
    VALKEY_SLOWLOG_LEN=$("${RCLI[@]}" SLOWLOG LEN 2>/dev/null || echo "0")
    VALKEY_CLIENT_LIST=$("${RCLI[@]}" CLIENT LIST 2>/dev/null || echo "")
    VALKEY_DBSIZE=$("${RCLI[@]}" DBSIZE 2>/dev/null || echo "")
    VALKEY_MAXMEMORY_POLICY=$("${RCLI[@]}" CONFIG GET maxmemory-policy 2>/dev/null | tail -1 || echo "")
    VALKEY_TIMEOUT=$("${RCLI[@]}" CONFIG GET timeout 2>/dev/null | tail -1 || echo "")
    VALKEY_HZ=$("${RCLI[@]}" CONFIG GET hz 2>/dev/null | tail -1 || echo "")
    VALKEY_SLOWLOG_THRESHOLD=$("${RCLI[@]}" CONFIG GET slowlog-log-slower-than 2>/dev/null | tail -1 || echo "")

    log_success "Valkey/Redis: Data collected"
}
