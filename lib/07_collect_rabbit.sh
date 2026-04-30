#!/bin/bash
# =============================================================================
# 07_collect_rabbit.sh - RabbitMQ Data Collection
# =============================================================================
# Connects to RabbitMQ Management HTTP API and collects metrics for scoring.
# Uses multi-round retry with host/port/protocol permutations (HTTP + HTTPS).
#
# Populates: RMQ_RAW_DATA, RMQ_QUEUES_DATA, RMQ_NODES_DATA,
#            RMQ_CONNECTIONS_DATA, RMQ_CHANNELS_DATA, RMQ_VHOSTS_DATA,
#            RMQ_EXCHANGES_DATA, RMQ_BINDINGS_DATA
#
# Compatibility: Bash 3.2+ (no associative arrays, no namerefs)
# =============================================================================

collect_rabbitmq_data() {
    if [ "$CURL_AVAILABLE" != "true" ]; then
        attention_add "RabbitMQ" "WARNING" "curl not available — RabbitMQ collection skipped. Install curl to enable."
        EXTERNAL_RABBITMQ_STATUS="client_not_available"
        return 0
    fi
    if [ -z "$EXTERNAL_RABBITMQ_HOST" ] || [ -z "$EXTERNAL_RABBITMQ_USER" ] || [ -z "$EXTERNAL_RABBITMQ_PASS" ]; then
        log_warning "RabbitMQ: Missing connection info (host/user/pass not configured)"
        attention_add "RabbitMQ" "WARNING" "RabbitMQ host/user/pass not fully configured — collection skipped. Set EXTERNAL_RABBITMQ_HOST, EXTERNAL_RABBITMQ_USER, and EXTERNAL_RABBITMQ_PASS."
        EXTERNAL_RABBITMQ_STATUS="not_configured"
        return 0
    fi

    local RESOLVED_RABBITMQ_HOST
    RESOLVED_RABBITMQ_HOST=$(resolve_host_for_local "$EXTERNAL_RABBITMQ_HOST")

    local RMQ_CONNECTED=false

    local HOSTS_TO_TRY
    read -ra HOSTS_TO_TRY <<< "$(build_connection_hosts "$EXTERNAL_RABBITMQ_HOST" "$RESOLVED_RABBITMQ_HOST")"

    local PORTS_TO_TRY=("$EXTERNAL_RABBITMQ_PORT")
    [ "$EXTERNAL_RABBITMQ_PORT" != "15672" ] && PORTS_TO_TRY+=("15672")

    local HTTPS_PORTS=("$EXTERNAL_RABBITMQ_PORT")
    [ "$EXTERNAL_RABBITMQ_PORT" != "15671" ] && HTTPS_PORTS+=("15671")

    local RABBITMQ_URL=""
    local ENCODED_RMQ_USER ENCODED_RMQ_PASS
    ENCODED_RMQ_USER=$(urlencode "$EXTERNAL_RABBITMQ_USER")
    ENCODED_RMQ_PASS=$(urlencode "$EXTERNAL_RABBITMQ_PASS")

    log_info "RabbitMQ: Attempting connection (hosts: ${HOSTS_TO_TRY[*]}, ports: ${PORTS_TO_TRY[*]})"

    local round_delay=2
    for (( round=1; round<=3; round++ )); do
        if [ $round -gt 1 ]; then
            log_info "RabbitMQ: Retry round $round/3 (waiting ${round_delay}s)..."
            sleep "$round_delay"
            round_delay=$((round_delay * 2))
        fi
        for try_host in "${HOSTS_TO_TRY[@]}"; do
            for try_port in "${PORTS_TO_TRY[@]}"; do
                RABBITMQ_URL="http://${ENCODED_RMQ_USER}:${ENCODED_RMQ_PASS}@$try_host:$try_port/api"
                if curl -sf --connect-timeout 5 "$RABBITMQ_URL/overview" &>/dev/null; then
                    RESOLVED_RABBITMQ_HOST="$try_host"
                    EXTERNAL_RABBITMQ_PORT="$try_port"
                    RMQ_CONNECTED=true
                    break 3
                fi
            done
        done
        for try_host in "${HOSTS_TO_TRY[@]}"; do
            for try_port in "${HTTPS_PORTS[@]}"; do
                RABBITMQ_URL="https://${ENCODED_RMQ_USER}:${ENCODED_RMQ_PASS}@$try_host:$try_port/api"
                if curl -sf --connect-timeout 5 --insecure "$RABBITMQ_URL/overview" &>/dev/null; then
                    RESOLVED_RABBITMQ_HOST="$try_host"
                    EXTERNAL_RABBITMQ_PORT="$try_port"
                    RMQ_CONNECTED=true
                    break 3
                fi
            done
        done
    done

    if [ "$RMQ_CONNECTED" != "true" ]; then
        log_warning "RabbitMQ: All connection attempts failed after 3 rounds"
        log_warning "  Hosts tried: ${HOSTS_TO_TRY[*]}"
        log_warning "  Ports tried: ${PORTS_TO_TRY[*]} (+ ${HTTPS_PORTS[*]} for HTTPS)"
        log_warning "  Protocols tried: HTTP, HTTPS"
        attention_add "RabbitMQ" "ERROR" "Unable to connect to RabbitMQ at ${EXTERNAL_RABBITMQ_HOST:-unknown}:${EXTERNAL_RABBITMQ_PORT:-15672} — all host/port/protocol combinations failed after 3 rounds. Check connection credentials and network access."
        EXTERNAL_RABBITMQ_STATUS="connection_failed"
        return 0
    fi

    log_success "RabbitMQ: Connected to $RESOLVED_RABBITMQ_HOST:$EXTERNAL_RABBITMQ_PORT"
    EXTERNAL_RABBITMQ_STATUS="connected"

    RMQ_RAW_DATA=$(curl -sf --max-time 30 "$RABBITMQ_URL/overview" 2>/dev/null || echo "{}")
    if [ -z "$RMQ_RAW_DATA" ] || [ "$RMQ_RAW_DATA" = "{}" ]; then
        attention_add "RabbitMQ" "ERROR" "RabbitMQ /api/overview returned empty from ${RESOLVED_RABBITMQ_HOST}:${EXTERNAL_RABBITMQ_PORT} — connected but unable to retrieve metrics. Check management plugin and user permissions."
        EXTERNAL_RABBITMQ_STATUS="error"
        return 0
    fi
    RMQ_QUEUES_DATA=$(curl -sf --max-time 30 "$RABBITMQ_URL/queues" 2>/dev/null || echo "[]")
    RMQ_NODES_DATA=$(curl -sf --max-time 30 "$RABBITMQ_URL/nodes" 2>/dev/null || echo "[]")
    RMQ_CONNECTIONS_DATA=$(curl -sf --max-time 30 "$RABBITMQ_URL/connections" 2>/dev/null || echo "[]")
    RMQ_CHANNELS_DATA=$(curl -sf --max-time 30 "$RABBITMQ_URL/channels" 2>/dev/null || echo "[]")
    RMQ_VHOSTS_DATA=$(curl -sf --max-time 30 "$RABBITMQ_URL/vhosts" 2>/dev/null || echo "[]")
    RMQ_EXCHANGES_DATA=$(curl -sf --max-time 30 "$RABBITMQ_URL/exchanges" 2>/dev/null || echo "[]")
    RMQ_BINDINGS_DATA=$(curl -sf --max-time 30 "$RABBITMQ_URL/bindings" 2>/dev/null || echo "[]")

    # Check for partial failures on supplementary endpoints
    if [ "$RMQ_NODES_DATA" = "[]" ]; then
        attention_add "RabbitMQ" "WARNING" "RabbitMQ /api/nodes returned empty — cluster node metrics unavailable. Check user tags (requires 'monitoring' tag)."
    fi

    log_success "RabbitMQ: Data collected"
}
