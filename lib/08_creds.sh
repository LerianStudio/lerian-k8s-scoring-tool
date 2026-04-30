#!/bin/bash
# =============================================================================
# 08_creds.sh - Database Credential Discovery
# =============================================================================
# Discovers database connection info from Kubernetes ConfigMaps/Secrets,
# Docker containers, or environment variables.
#
# Strategy (in priority order):
#   1. Environment variables (EXTERNAL_PG_HOST, etc.) -- already set, skip
#   2. Well-known ConfigMap names (midaz-onboarding, midaz-transaction, midaz-ledger)
#   3. Dynamic scan of all ConfigMaps/Secrets in target namespaces
#   4. Docker container fallback (for local dev environments)
#
# Compatibility: Bash 3.2+ (no associative arrays, no namerefs)
# =============================================================================

fetch_k8s_db_credentials() {
    # Fetches ALL database connection info (host, port, user, pass, databases)
    # from Kubernetes ConfigMaps and Secrets in the target namespaces.
    # Only populates values not already set via environment variables.
    #
    # Discovery strategy (in order):
    #   1. Try well-known configmap names (midaz-onboarding, midaz-transaction, midaz-ledger)
    #   2. If not found, dynamically discover configmaps containing DB keys
    #      (handles Terraform/Helm deployments with custom release names)

    if ! command -v kubectl &> /dev/null; then
        return 0
    fi
    if ! kubectl cluster-info &> /dev/null 2>&1; then
        return 0
    fi

    log_info "Fetching database connection info from Kubernetes ConfigMaps and Secrets..."

    # Helper: get a value from a K8s configmap (tries all target namespaces)
    # Usage: k8s_cm_val <configmap-name> <key>
    k8s_cm_val() {
        local cm_name="$1" cm_key="$2"
        local IFS_BAK="$IFS"
        IFS=';'
        for ns in $TARGET_NAMESPACES; do
            ns=$(trim "$ns")
            if [ -z "$ns" ] || [ "$ns" = "all" ]; then ns="midaz"; fi
            local val
            val=$(kubectl get configmap "$cm_name" -n "$ns" -o jsonpath="{.data.$cm_key}" 2>/dev/null || true)
            if [ -n "$val" ]; then
                IFS="$IFS_BAK"
                echo "$val"
                return
            fi
        done
        IFS="$IFS_BAK"
    }

    # Helper: get a decoded secret value (tries all target namespaces)
    # Usage: k8s_secret_val <secret-name> <key>
    k8s_secret_val() {
        local secret_name="$1" secret_key="$2"
        local IFS_BAK="$IFS"
        IFS=';'
        for ns in $TARGET_NAMESPACES; do
            ns=$(trim "$ns")
            if [ -z "$ns" ] || [ "$ns" = "all" ]; then ns="midaz"; fi
            local raw
            raw=$(kubectl get secret "$secret_name" -n "$ns" -o jsonpath="{.data.$secret_key}" 2>/dev/null) || true
            if [ -n "$raw" ]; then
                IFS="$IFS_BAK"
                # macOS uses base64 -D, Linux uses base64 -d
                echo "$raw" | base64 --decode 2>/dev/null || echo "$raw" | base64 -d 2>/dev/null || echo "$raw" | base64 -D 2>/dev/null || true
                return
            fi
        done
        IFS="$IFS_BAK"
    }

    # =========================================================================
    # PHASE 1: Well-known ConfigMaps (original behavior -- always runs first)
    # =========================================================================
    # Try the hardcoded configmap names that match standard Helm deployments
    # where the release name is "midaz" (midaz-onboarding, midaz-transaction, etc.)
    log_info "Phase 1: Trying well-known configmap names..."

    # --- PostgreSQL (well-known) ---
    if [ -z "$EXTERNAL_PG_HOST" ]; then
        for cm in midaz-onboarding midaz-transaction midaz-ledger; do
            local val=""
            for key in DB_HOST DB_ONBOARDING_HOST DB_TRANSACTION_HOST; do
                val=$(k8s_cm_val "$cm" "$key")
                if [ -n "$val" ]; then
                    EXTERNAL_PG_HOST="$val"
                    log_info " PostgreSQL host from configmap/$cm ($key): $val"
                    break 2
                fi
            done
        done
    fi
    if [ -z "$EXTERNAL_PG_PORT" ]; then
        for cm in midaz-onboarding midaz-transaction midaz-ledger; do
            local val=""
            for key in DB_PORT DB_ONBOARDING_PORT DB_TRANSACTION_PORT; do
                val=$(k8s_cm_val "$cm" "$key")
                if [ -n "$val" ]; then
                    EXTERNAL_PG_PORT="$val"
                    break 2
                fi
            done
        done
    fi
    if [ -z "$EXTERNAL_PG_USER" ]; then
        for cm in midaz-onboarding midaz-transaction midaz-ledger; do
            local val=""
            for key in DB_USER DB_ONBOARDING_USER DB_TRANSACTION_USER; do
                val=$(k8s_cm_val "$cm" "$key")
                if [ -n "$val" ]; then
                    EXTERNAL_PG_USER="$val"
                    break 2
                fi
            done
        done
    fi
    if [ -z "$EXTERNAL_PG_PASS" ]; then
        for secret_name in midaz-ledger midaz-onboarding midaz-transaction; do
            local val=""
            for key in DB_PASSWORD DB_ONBOARDING_PASSWORD DB_TRANSACTION_PASSWORD password postgres-password; do
                val=$(k8s_secret_val "$secret_name" "$key")
                if [ -n "$val" ]; then break; fi
            done
            if [ -n "$val" ]; then
                EXTERNAL_PG_PASS="$val"
                log_info " PostgreSQL password from secret/$secret_name"
                break
            fi
        done
    fi
    if [ -z "$EXTERNAL_PG_DATABASES" ]; then
        local pg_dbs=""
        for cm in midaz-onboarding midaz-transaction midaz-ledger; do
            for key in DB_NAME DB_ONBOARDING_NAME DB_TRANSACTION_NAME; do
                local val
                val=$(k8s_cm_val "$cm" "$key")
                if [ -n "$val" ]; then
                    if ! echo ",$pg_dbs," | grep -q ",$val,"; then
                        if [ -n "$pg_dbs" ]; then pg_dbs+=","; fi
                        pg_dbs+="$val"
                    fi
                fi
            done
        done
        if [ -n "$pg_dbs" ]; then
            EXTERNAL_PG_DATABASES="$pg_dbs"
            log_info " PostgreSQL databases: $pg_dbs"
        fi
    fi

    # --- MongoDB (well-known) ---
    if [ -z "$EXTERNAL_MONGO_HOST" ]; then
        for cm in midaz-onboarding midaz-transaction midaz-ledger; do
            local val=""
            for key in MONGO_HOST MONGO_ONBOARDING_HOST MONGO_TRANSACTION_HOST; do
                val=$(k8s_cm_val "$cm" "$key")
                if [ -n "$val" ]; then
                    EXTERNAL_MONGO_HOST="$val"
                    log_info " MongoDB host from configmap/$cm ($key): $val"
                    break 2
                fi
            done
        done
    fi
    if [ -z "$EXTERNAL_MONGO_PORT" ]; then
        for cm in midaz-onboarding midaz-transaction midaz-ledger; do
            local val=""
            for key in MONGO_PORT MONGO_ONBOARDING_PORT MONGO_TRANSACTION_PORT; do
                val=$(k8s_cm_val "$cm" "$key")
                if [ -n "$val" ]; then
                    EXTERNAL_MONGO_PORT="$val"
                    break 2
                fi
            done
        done
    fi
    if [ -z "$EXTERNAL_MONGO_USER" ]; then
        for cm in midaz-onboarding midaz-transaction midaz-ledger; do
            local val=""
            for key in MONGO_USER MONGO_ONBOARDING_USER MONGO_TRANSACTION_USER; do
                val=$(k8s_cm_val "$cm" "$key")
                if [ -n "$val" ]; then
                    EXTERNAL_MONGO_USER="$val"
                    break 2
                fi
            done
        done
    fi
    if [ -z "$EXTERNAL_MONGO_PASS" ]; then
        for secret_name in midaz-ledger midaz-onboarding midaz-transaction; do
            local val=""
            for key in MONGO_PASSWORD MONGO_ONBOARDING_PASSWORD MONGO_TRANSACTION_PASSWORD password mongodb-password; do
                val=$(k8s_secret_val "$secret_name" "$key")
                if [ -n "$val" ]; then break; fi
            done
            if [ -n "$val" ]; then
                EXTERNAL_MONGO_PASS="$val"
                log_info " MongoDB password from secret/$secret_name"
                break
            fi
        done
    fi
    if [ -z "$EXTERNAL_MONGO_DATABASES" ]; then
        local mongo_dbs=""
        for cm in midaz-onboarding midaz-transaction midaz-ledger; do
            for key in MONGO_NAME MONGO_ONBOARDING_NAME MONGO_TRANSACTION_NAME; do
                local val
                val=$(k8s_cm_val "$cm" "$key")
                if [ -n "$val" ]; then
                    if ! echo ",$mongo_dbs," | grep -q ",$val,"; then
                        if [ -n "$mongo_dbs" ]; then mongo_dbs+=","; fi
                        mongo_dbs+="$val"
                    fi
                fi
            done
        done
        if [ -n "$mongo_dbs" ]; then
            EXTERNAL_MONGO_DATABASES="$mongo_dbs"
            log_info " MongoDB databases: $mongo_dbs"
        fi
    fi

    # --- Redis/Valkey (well-known) ---
    if [ -z "$EXTERNAL_REDIS_HOST" ] || [ -z "$EXTERNAL_REDIS_PORT" ]; then
        for cm in midaz-onboarding midaz-transaction midaz-ledger; do
            local val
            val=$(k8s_cm_val "$cm" "REDIS_HOST")
            if [ -n "$val" ]; then
                if [[ "$val" == *:* ]]; then
                    if [ -z "$EXTERNAL_REDIS_HOST" ]; then
                        EXTERNAL_REDIS_HOST="${val%%:*}"
                    fi
                    if [ -z "$EXTERNAL_REDIS_PORT" ]; then
                        EXTERNAL_REDIS_PORT="${val##*:}"
                    fi
                else
                    if [ -z "$EXTERNAL_REDIS_HOST" ]; then
                        EXTERNAL_REDIS_HOST="$val"
                    fi
                fi
                log_info " Redis host from configmap/$cm: ${EXTERNAL_REDIS_HOST}:${EXTERNAL_REDIS_PORT:-6379}"
                break
            fi
        done
    fi
    if [ -z "$EXTERNAL_REDIS_PASS" ]; then
        for secret_name in midaz-ledger midaz-onboarding midaz-transaction; do
            local val=""
            for key in REDIS_PASSWORD redis-password password; do
                val=$(k8s_secret_val "$secret_name" "$key")
                if [ -n "$val" ]; then break; fi
            done
            if [ -n "$val" ]; then
                EXTERNAL_REDIS_PASS="$val"
                log_info " Redis password from secret/$secret_name"
                break
            fi
        done
    fi

    # --- RabbitMQ (well-known) ---
    if [ -z "$EXTERNAL_RABBITMQ_HOST" ]; then
        for cm in midaz-transaction midaz-ledger; do
            local val
            val=$(k8s_cm_val "$cm" "RABBITMQ_HOST")
            if [ -n "$val" ]; then
                EXTERNAL_RABBITMQ_HOST="${val%.}"
                log_info " RabbitMQ host from configmap/$cm: $EXTERNAL_RABBITMQ_HOST"
                break
            fi
        done
    fi
    if [ -z "$EXTERNAL_RABBITMQ_PORT" ]; then
        for cm in midaz-transaction midaz-ledger; do
            local val
            val=$(k8s_cm_val "$cm" "RABBITMQ_PORT_AMQP")
            if [ -n "$val" ]; then
                EXTERNAL_RABBITMQ_PORT="$val"
                break
            fi
        done
    fi
    if [ -z "$EXTERNAL_RABBITMQ_USER" ]; then
        for cm in midaz-transaction midaz-ledger; do
            local val
            val=$(k8s_cm_val "$cm" "RABBITMQ_DEFAULT_USER")
            if [ -n "$val" ]; then
                EXTERNAL_RABBITMQ_USER="$val"
                break
            fi
        done
    fi
    if [ -z "$EXTERNAL_RABBITMQ_PASS" ]; then
        for secret_name in midaz-ledger midaz-transaction midaz-onboarding; do
            local val=""
            for key in RABBITMQ_DEFAULT_PASS RABBITMQ_CONSUMER_PASS rabbitmq-password password; do
                val=$(k8s_secret_val "$secret_name" "$key")
                if [ -n "$val" ]; then break; fi
            done
            if [ -n "$val" ]; then
                EXTERNAL_RABBITMQ_PASS="$val"
                log_info " RabbitMQ password from secret/$secret_name"
                break
            fi
        done
    fi

    # =========================================================================
    # PHASE 2: Dynamic ConfigMap Discovery (Terraform/custom Helm fallback)
    # =========================================================================
    # Only runs if Phase 1 left gaps. Scans all configmaps in target namespaces
    # for known DB keys (DB_HOST, MONGO_HOST, etc.) regardless of configmap name.
    # This handles Terraform/Helm deployments with custom release names where
    # configmaps are named "<release>-onboarding", "<release>-transaction", etc.

    local needs_dynamic=false
    if [ -z "$EXTERNAL_PG_HOST" ] || [ -z "$EXTERNAL_MONGO_HOST" ] || [ -z "$EXTERNAL_REDIS_HOST" ] || [ -z "$EXTERNAL_RABBITMQ_HOST" ]; then
        needs_dynamic=true
    fi
    if [ -z "$EXTERNAL_PG_PASS" ] || [ -z "$EXTERNAL_MONGO_PASS" ] || [ -z "$EXTERNAL_REDIS_PASS" ] || [ -z "$EXTERNAL_RABBITMQ_PASS" ]; then
        needs_dynamic=true
    fi

    if [ "$needs_dynamic" = true ]; then
        log_info "Phase 2: Some credentials missing -- scanning all configmaps for Terraform/Helm patterns..."

        local IFS_BAK="$IFS"
        IFS=';'
        for ns in $TARGET_NAMESPACES; do
            ns=$(trim "$ns")
            if [ -z "$ns" ] || [ "$ns" = "all" ]; then ns="midaz"; fi

            # Get all configmap names in this namespace
            local all_cms
            all_cms=$(kubectl get configmaps -n "$ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)

            for cm_name in $all_cms; do
                # Skip well-known names (already tried in Phase 1) and noise
                case "$cm_name" in
                    midaz-onboarding|midaz-transaction|midaz-ledger) continue ;;
                    kube-*|kubernetes-*|coredns*|calico*|istio*|cert-manager*) continue ;;
                esac

                # Get all keys in this configmap
                local cm_keys
                cm_keys=$(kubectl get configmap "$cm_name" -n "$ns" -o go-template='{{range $k,$v := .data}}{{$k}}{{"\n"}}{{end}}' 2>/dev/null || true)

                # --- PostgreSQL from dynamic configmaps ---
                if [ -z "$EXTERNAL_PG_HOST" ]; then
                    if echo "$cm_keys" | grep -qE '^(DB_HOST|DB_ONBOARDING_HOST|DB_TRANSACTION_HOST)$'; then
                        local val
                        for key in DB_HOST DB_ONBOARDING_HOST DB_TRANSACTION_HOST; do
                            val=$(k8s_cm_val "$cm_name" "$key")
                            if [ -n "$val" ]; then
                                EXTERNAL_PG_HOST="$val"
                                log_info " PostgreSQL host from configmap/$cm_name ($key): $val"
                                break
                            fi
                        done
                    fi
                fi
                if [ -z "$EXTERNAL_PG_PORT" ]; then
                    for key in DB_PORT DB_ONBOARDING_PORT DB_TRANSACTION_PORT; do
                        local val
                        val=$(k8s_cm_val "$cm_name" "$key")
                        if [ -n "$val" ]; then
                            EXTERNAL_PG_PORT="$val"
                            break
                        fi
                    done
                fi
                if [ -z "$EXTERNAL_PG_USER" ]; then
                    for key in DB_USER DB_ONBOARDING_USER DB_TRANSACTION_USER; do
                        local val
                        val=$(k8s_cm_val "$cm_name" "$key")
                        if [ -n "$val" ]; then
                            EXTERNAL_PG_USER="$val"
                            break
                        fi
                    done
                fi
                if [ -z "$EXTERNAL_PG_DATABASES" ]; then
                    local pg_dbs=""
                    for key in DB_NAME DB_ONBOARDING_NAME DB_TRANSACTION_NAME; do
                        local val
                        val=$(k8s_cm_val "$cm_name" "$key")
                        if [ -n "$val" ]; then
                            if ! echo ",$pg_dbs," | grep -q ",$val,"; then
                                if [ -n "$pg_dbs" ]; then pg_dbs+=","; fi
                                pg_dbs+="$val"
                            fi
                        fi
                    done
                    if [ -n "$pg_dbs" ]; then
                        EXTERNAL_PG_DATABASES="$pg_dbs"
                        log_info " PostgreSQL databases from configmap/$cm_name: $pg_dbs"
                    fi
                fi

                # --- MongoDB from dynamic configmaps ---
                if [ -z "$EXTERNAL_MONGO_HOST" ]; then
                    if echo "$cm_keys" | grep -qE '^(MONGO_HOST|MONGO_ONBOARDING_HOST|MONGO_TRANSACTION_HOST)$'; then
                        local val
                        for key in MONGO_HOST MONGO_ONBOARDING_HOST MONGO_TRANSACTION_HOST; do
                            val=$(k8s_cm_val "$cm_name" "$key")
                            if [ -n "$val" ]; then
                                EXTERNAL_MONGO_HOST="$val"
                                log_info " MongoDB host from configmap/$cm_name ($key): $val"
                                break
                            fi
                        done
                    fi
                fi
                if [ -z "$EXTERNAL_MONGO_PORT" ]; then
                    for key in MONGO_PORT MONGO_ONBOARDING_PORT MONGO_TRANSACTION_PORT; do
                        local val
                        val=$(k8s_cm_val "$cm_name" "$key")
                        if [ -n "$val" ]; then
                            EXTERNAL_MONGO_PORT="$val"
                            break
                        fi
                    done
                fi
                if [ -z "$EXTERNAL_MONGO_USER" ]; then
                    for key in MONGO_USER MONGO_ONBOARDING_USER MONGO_TRANSACTION_USER; do
                        local val
                        val=$(k8s_cm_val "$cm_name" "$key")
                        if [ -n "$val" ]; then
                            EXTERNAL_MONGO_USER="$val"
                            break
                        fi
                    done
                fi
                if [ -z "$EXTERNAL_MONGO_DATABASES" ]; then
                    local mongo_dbs=""
                    for key in MONGO_NAME MONGO_ONBOARDING_NAME MONGO_TRANSACTION_NAME; do
                        local val
                        val=$(k8s_cm_val "$cm_name" "$key")
                        if [ -n "$val" ]; then
                            if ! echo ",$mongo_dbs," | grep -q ",$val,"; then
                                if [ -n "$mongo_dbs" ]; then mongo_dbs+=","; fi
                                mongo_dbs+="$val"
                            fi
                        fi
                    done
                    if [ -n "$mongo_dbs" ]; then
                        EXTERNAL_MONGO_DATABASES="$mongo_dbs"
                        log_info " MongoDB databases from configmap/$cm_name: $mongo_dbs"
                    fi
                fi

                # --- Redis from dynamic configmaps ---
                if [ -z "$EXTERNAL_REDIS_HOST" ]; then
                    if echo "$cm_keys" | grep -qE '^REDIS_HOST$'; then
                        local val
                        val=$(k8s_cm_val "$cm_name" "REDIS_HOST")
                        if [ -n "$val" ]; then
                            if [[ "$val" == *:* ]]; then
                                EXTERNAL_REDIS_HOST="${val%%:*}"
                                if [ -z "$EXTERNAL_REDIS_PORT" ]; then
                                    EXTERNAL_REDIS_PORT="${val##*:}"
                                fi
                            else
                                EXTERNAL_REDIS_HOST="$val"
                            fi
                            log_info " Redis host from configmap/$cm_name: ${EXTERNAL_REDIS_HOST}:${EXTERNAL_REDIS_PORT:-6379}"
                        fi
                    fi
                fi

                # --- RabbitMQ from dynamic configmaps ---
                if [ -z "$EXTERNAL_RABBITMQ_HOST" ]; then
                    if echo "$cm_keys" | grep -qE '^RABBITMQ_HOST$'; then
                        local val
                        val=$(k8s_cm_val "$cm_name" "RABBITMQ_HOST")
                        if [ -n "$val" ]; then
                            EXTERNAL_RABBITMQ_HOST="${val%.}"
                            log_info " RabbitMQ host from configmap/$cm_name: $EXTERNAL_RABBITMQ_HOST"
                        fi
                    fi
                fi
                if [ -z "$EXTERNAL_RABBITMQ_PORT" ]; then
                    local val
                    val=$(k8s_cm_val "$cm_name" "RABBITMQ_PORT_AMQP")
                    if [ -n "$val" ]; then
                        EXTERNAL_RABBITMQ_PORT="$val"
                    fi
                fi
                if [ -z "$EXTERNAL_RABBITMQ_USER" ]; then
                    local val
                    val=$(k8s_cm_val "$cm_name" "RABBITMQ_DEFAULT_USER")
                    if [ -n "$val" ]; then
                        EXTERNAL_RABBITMQ_USER="$val"
                    fi
                fi
            done

            # --- Secrets from dynamic discovery ---
            local all_secrets
            all_secrets=$(kubectl get secrets -n "$ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
            for secret_name in $all_secrets; do
                # Skip well-known (already tried) and noise
                case "$secret_name" in
                    midaz-ledger|midaz-onboarding|midaz-transaction) continue ;;
                    kube-*|kubernetes-*|default-token-*|sh.helm.*) continue ;;
                esac

                if [ -z "$EXTERNAL_PG_PASS" ]; then
                    local val=""
                    for key in DB_PASSWORD DB_ONBOARDING_PASSWORD DB_TRANSACTION_PASSWORD password postgres-password; do
                        val=$(k8s_secret_val "$secret_name" "$key")
                        if [ -n "$val" ]; then break; fi
                    done
                    if [ -n "$val" ]; then
                        EXTERNAL_PG_PASS="$val"
                        log_info " PostgreSQL password from secret/$secret_name"
                    fi
                fi
                if [ -z "$EXTERNAL_MONGO_PASS" ]; then
                    local val=""
                    for key in MONGO_PASSWORD MONGO_ONBOARDING_PASSWORD MONGO_TRANSACTION_PASSWORD mongodb-password; do
                        val=$(k8s_secret_val "$secret_name" "$key")
                        if [ -n "$val" ]; then break; fi
                    done
                    if [ -n "$val" ]; then
                        EXTERNAL_MONGO_PASS="$val"
                        log_info " MongoDB password from secret/$secret_name"
                    fi
                fi
                if [ -z "$EXTERNAL_REDIS_PASS" ]; then
                    local val=""
                    for key in REDIS_PASSWORD redis-password; do
                        val=$(k8s_secret_val "$secret_name" "$key")
                        if [ -n "$val" ]; then break; fi
                    done
                    if [ -n "$val" ]; then
                        EXTERNAL_REDIS_PASS="$val"
                        log_info " Redis password from secret/$secret_name"
                    fi
                fi
                if [ -z "$EXTERNAL_RABBITMQ_PASS" ]; then
                    local val=""
                    for key in RABBITMQ_DEFAULT_PASS RABBITMQ_CONSUMER_PASS rabbitmq-password; do
                        val=$(k8s_secret_val "$secret_name" "$key")
                        if [ -n "$val" ]; then break; fi
                    done
                    if [ -n "$val" ]; then
                        EXTERNAL_RABBITMQ_PASS="$val"
                        log_info " RabbitMQ password from secret/$secret_name"
                    fi
                fi
            done
        done
        IFS="$IFS_BAK"
    else
        log_info "Phase 1 collected all database credentials -- skipping dynamic scan"
    fi

    # --- Docker container fallback ---
    # If K8s discovery didn't find hosts, try detecting local midaz Docker containers
    if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
        # PostgreSQL from midaz-postgresql container
        if [ -z "$EXTERNAL_PG_HOST" ] && docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^midaz-postgresql$'; then
            EXTERNAL_PG_HOST="127.0.0.1"
            local pg_port
            pg_port=$(docker inspect midaz-postgresql --format '{{range $p, $conf := .NetworkSettings.Ports}}{{if eq $p "5432/tcp"}}{{(index $conf 0).HostPort}}{{end}}{{end}}' 2>/dev/null)
            EXTERNAL_PG_PORT="${pg_port:-5432}"
            if [ -z "$EXTERNAL_PG_USER" ]; then
                EXTERNAL_PG_USER=$(docker inspect midaz-postgresql --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep '^POSTGRES_USER=' | cut -d= -f2- || true)
            fi
            if [ -z "$EXTERNAL_PG_PASS" ]; then
                EXTERNAL_PG_PASS=$(docker inspect midaz-postgresql --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep '^POSTGRES_PASSWORD=' | cut -d= -f2- || true)
            fi
            if [ -z "$EXTERNAL_PG_DATABASES" ]; then
                EXTERNAL_PG_DATABASES=$(docker inspect midaz-postgresql --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep '^POSTGRES_DB=' | cut -d= -f2- || true)
            fi
            log_info " PostgreSQL: detected from Docker container midaz-postgresql"
        fi

        # MongoDB from midaz-mongodb container
        if [ -z "$EXTERNAL_MONGO_HOST" ] && docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^midaz-mongodb$'; then
            EXTERNAL_MONGO_HOST="127.0.0.1"
            local mongo_port
            mongo_port=$(docker inspect midaz-mongodb --format '{{range $p, $conf := .NetworkSettings.Ports}}{{if eq $p "27017/tcp"}}{{(index $conf 0).HostPort}}{{end}}{{end}}' 2>/dev/null)
            EXTERNAL_MONGO_PORT="${mongo_port:-27017}"
            if [ -z "$EXTERNAL_MONGO_USER" ]; then
                EXTERNAL_MONGO_USER=$(docker inspect midaz-mongodb --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep '^MONGO_INITDB_ROOT_USERNAME=' | cut -d= -f2- || true)
            fi
            if [ -z "$EXTERNAL_MONGO_PASS" ]; then
                EXTERNAL_MONGO_PASS=$(docker inspect midaz-mongodb --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep '^MONGO_INITDB_ROOT_PASSWORD=' | cut -d= -f2- || true)
            fi
            log_info " MongoDB: detected from Docker container midaz-mongodb"
        fi

        # Valkey/Redis from midaz-valkey container
        if [ -z "$EXTERNAL_REDIS_HOST" ] && docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^midaz-valkey$'; then
            EXTERNAL_REDIS_HOST="127.0.0.1"
            local redis_port
            redis_port=$(docker inspect midaz-valkey --format '{{range $p, $conf := .NetworkSettings.Ports}}{{if eq $p "6379/tcp"}}{{(index $conf 0).HostPort}}{{end}}{{end}}' 2>/dev/null)
            EXTERNAL_REDIS_PORT="${redis_port:-6379}"
            if [ -z "$EXTERNAL_REDIS_PASS" ]; then
                local rpass
                rpass=$(docker inspect midaz-valkey --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep '^REDIS_PASSWORD\|^VALKEY_PASSWORD' | head -1 | cut -d= -f2- || true)
                EXTERNAL_REDIS_PASS="${rpass:-}"
            fi
            log_info " Redis/Valkey: detected from Docker container midaz-valkey"
        fi

        # RabbitMQ from midaz-rabbitmq container
        if [ -z "$EXTERNAL_RABBITMQ_HOST" ] && docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^midaz-rabbitmq$'; then
            EXTERNAL_RABBITMQ_HOST="127.0.0.1"
            local rmq_port
            rmq_port=$(docker inspect midaz-rabbitmq --format '{{range $p, $conf := .NetworkSettings.Ports}}{{if eq $p "15672/tcp"}}{{(index $conf 0).HostPort}}{{end}}{{end}}' 2>/dev/null)
            EXTERNAL_RABBITMQ_PORT="${rmq_port:-15672}"
            if [ -z "$EXTERNAL_RABBITMQ_USER" ]; then
                EXTERNAL_RABBITMQ_USER=$(docker inspect midaz-rabbitmq --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep '^RABBITMQ_DEFAULT_USER=' | cut -d= -f2- || true)
            fi
            if [ -z "$EXTERNAL_RABBITMQ_PASS" ]; then
                EXTERNAL_RABBITMQ_PASS=$(docker inspect midaz-rabbitmq --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep '^RABBITMQ_DEFAULT_PASS=' | cut -d= -f2- || true)
            fi
            log_info " RabbitMQ: detected from Docker container midaz-rabbitmq"
        fi
    fi

    # Apply defaults for any values still empty after K8s fetch
    EXTERNAL_PG_PORT="${EXTERNAL_PG_PORT:-5432}"
    EXTERNAL_REDIS_PORT="${EXTERNAL_REDIS_PORT:-6379}"
    EXTERNAL_MONGO_PORT="${EXTERNAL_MONGO_PORT:-27017}"
    EXTERNAL_RABBITMQ_PORT="${EXTERNAL_RABBITMQ_PORT:-15672}"

    # Log summary
    if [ -n "$EXTERNAL_PG_HOST" ]; then
        log_success " PostgreSQL: ${EXTERNAL_PG_HOST}:${EXTERNAL_PG_PORT} user=${EXTERNAL_PG_USER} dbs=${EXTERNAL_PG_DATABASES}"
    else
        log_warning " PostgreSQL: No connection info found in K8s or env vars"
    fi
    if [ -n "$EXTERNAL_MONGO_HOST" ]; then
        log_success " MongoDB: ${EXTERNAL_MONGO_HOST}:${EXTERNAL_MONGO_PORT} user=${EXTERNAL_MONGO_USER} dbs=${EXTERNAL_MONGO_DATABASES}"
    else
        log_warning " MongoDB: No connection info found in K8s or env vars"
    fi
    if [ -n "$EXTERNAL_REDIS_HOST" ]; then
        log_success " Redis: ${EXTERNAL_REDIS_HOST}:${EXTERNAL_REDIS_PORT}"
    else
        log_warning " Redis: No connection info found in K8s or env vars"
    fi
    if [ -n "$EXTERNAL_RABBITMQ_HOST" ]; then
        log_success " RabbitMQ: ${EXTERNAL_RABBITMQ_HOST}:${EXTERNAL_RABBITMQ_PORT} user=${EXTERNAL_RABBITMQ_USER}"
    else
        log_warning " RabbitMQ: No connection info found in K8s or env vars"
    fi
}

# -----------------------------------------------------------------------------
# clear_db_credentials - Securely clear passwords from memory
# -----------------------------------------------------------------------------
clear_db_credentials() {
    unset EXTERNAL_PG_PASS
    unset EXTERNAL_MONGO_PASS
    unset EXTERNAL_REDIS_PASS
    unset EXTERNAL_RABBITMQ_PASS
    log_info "Database credentials cleared from memory"
}
