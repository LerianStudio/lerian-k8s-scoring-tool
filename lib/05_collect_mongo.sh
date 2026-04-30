#!/bin/bash
# =============================================================================
# 05_collect_mongo.sh - MongoDB / DocumentDB Data Collection
# =============================================================================
# Connects to MongoDB (or AWS DocumentDB) and collects metrics for scoring.
# Uses multi-round retry with host/port/TLS permutations.
# Auto-detects DocumentDB engine.
#
# Populates: MONGO_RAW_DATA, MONGO_DATABASES_DATA, MONGO_COLLECTIONS_DATA
#
# Compatibility: Bash 3.2+ (no associative arrays, no namerefs)
# =============================================================================

# -----------------------------------------------------------------------------
# urlencode - URL-encode a string (RFC 3986)
# -----------------------------------------------------------------------------
# Handles special characters in MongoDB credentials.
# Uses jq when available; falls back to character-by-character ASCII encoding.
#
# Arguments:
#   $1 - string to encode
# Returns:
#   Encoded string on stdout
# -----------------------------------------------------------------------------
urlencode() {
    local string="$1"
    if [ -z "$string" ]; then
        echo ""
        return
    fi
    if [ "$JQ_AVAILABLE" = "true" ]; then
        printf '%s' "$string" | jq -sRr @uri 2>/dev/null || printf '%s' "$string"
    else
        # Fallback: character-by-character approach (ASCII only)
        local strlen=${#string}
        local encoded=""
        local pos c o
        for (( pos=0 ; pos<strlen ; pos++ )); do
            c=${string:$pos:1}
            case "$c" in
                [-_.~a-zA-Z0-9]) o="$c" ;;
                *) printf -v o '%%%02X' "'$c" ;;
            esac
            encoded+="$o"
        done
        echo "$encoded"
    fi
}

# -----------------------------------------------------------------------------
# build_mongo_uri - Build a MongoDB connection URI
# -----------------------------------------------------------------------------
# Constructs a full mongodb:// URI with optional auth, TLS, and engine-
# specific query parameters.
#
# Arguments:
#   $1 - host
#   $2 - port
#   $3 - user     (may be empty)
#   $4 - password  (may be empty)
#   $5 - database  (default: admin)
#   $6 - use_tls   (true|false, default: false)
# Globals read:
#   EXTERNAL_MONGO_ENGINE - if "documentdb", appends retryWrites=false
# Returns:
#   URI string on stdout
# -----------------------------------------------------------------------------
build_mongo_uri() {
    local host="$1"
    local port="$2"
    local user="$3"
    local pass="$4"
    local db="${5:-admin}"
    local use_tls="${6:-false}"
    local base_uri=""

    if [ -n "$user" ] && [ -n "$pass" ]; then
        local encoded_user
        local encoded_pass
        encoded_user=$(urlencode "$user")
        encoded_pass=$(urlencode "$pass")
        base_uri="mongodb://${encoded_user}:${encoded_pass}@${host}:${port}/${db}"
    else
        base_uri="mongodb://${host}:${port}/${db}"
    fi

    local query_params="serverSelectionTimeoutMS=5000&authSource=admin"
    if [ "$EXTERNAL_MONGO_ENGINE" = "documentdb" ]; then
        query_params="${query_params}&retryWrites=false"
    fi
    if [ "$use_tls" = "true" ]; then
        query_params="${query_params}&tls=true&tlsAllowInvalidCertificates=true"
    fi

    echo "${base_uri}?${query_params}"
}

# -----------------------------------------------------------------------------
# collect_mongodb_data - Main MongoDB / DocumentDB collection function
# -----------------------------------------------------------------------------
# 1. Validates prerequisites (MONGO_AVAILABLE, host)
# 2. Multi-round retry with host/port/TLS permutations
# 3. Auto-detects DocumentDB engine via buildInfo
# 4. Collects server status, replica set, storage, oplog, and collection data
#
# Globals written:
#   EXTERNAL_MONGO_STATUS  - connection outcome
#   EXTERNAL_MONGO_ENGINE  - detected engine (mongodb|documentdb)
#   MONGO_RAW_DATA         - JSON with server metrics
#   MONGO_DATABASES_DATA   - JSON array of per-database stats
#   MONGO_COLLECTIONS_DATA - JSON array of all collections with index details
# -----------------------------------------------------------------------------
collect_mongodb_data() {
    if [ "$MONGO_AVAILABLE" != "true" ]; then
        attention_add "MongoDB" "WARNING" "mongosh/mongo client not available — MongoDB collection skipped. Install mongosh to enable."
        EXTERNAL_MONGO_STATUS="client_not_available"
        return 0
    fi
    if [ -z "$EXTERNAL_MONGO_HOST" ]; then
        log_warning "MongoDB: Missing connection info (host not configured)"
        attention_add "MongoDB" "WARNING" "MongoDB host not configured — collection skipped. Set EXTERNAL_MONGO_HOST."
        EXTERNAL_MONGO_STATUS="not_configured"
        return 0
    fi

    local RESOLVED_MONGO_HOST
    RESOLVED_MONGO_HOST=$(resolve_host_for_local "$EXTERNAL_MONGO_HOST")

    local MONGO_CONNECTED=false
    local MONGO_TLS_MODE="false"

    local HOSTS_TO_TRY
    read -ra HOSTS_TO_TRY <<< "$(build_connection_hosts "$EXTERNAL_MONGO_HOST" "$RESOLVED_MONGO_HOST")"

    local PORTS_TO_TRY=("$EXTERNAL_MONGO_PORT")
    [ "$EXTERNAL_MONGO_PORT" != "27017" ] && PORTS_TO_TRY+=("27017")

    local TLS_MODES=("false" "true")

    log_info "MongoDB: Attempting connection (hosts: ${HOSTS_TO_TRY[*]}, ports: ${PORTS_TO_TRY[*]})"

    # -----------------------------------------------------------------
    # Connection: 3-round retry with host/port/TLS permutations
    # -----------------------------------------------------------------
    local MONGO_URI=""
    local round_delay=2
    for (( round=1; round<=3; round++ )); do
        if [ $round -gt 1 ]; then
            log_info "MongoDB: Retry round $round/3 (waiting ${round_delay}s)..."
            sleep "$round_delay"
            round_delay=$((round_delay * 2))
        fi
        for try_host in "${HOSTS_TO_TRY[@]}"; do
            for try_port in "${PORTS_TO_TRY[@]}"; do
                for try_tls in "${TLS_MODES[@]}"; do
                    MONGO_URI=$(build_mongo_uri "$try_host" "$try_port" \
                        "$EXTERNAL_MONGO_USER" "$EXTERNAL_MONGO_PASS" "admin" "$try_tls")
                    if $MONGO_CMD "$MONGO_URI" --quiet \
                        --eval "db.runCommand({ping: 1})" &>/dev/null 2>&1; then
                        RESOLVED_MONGO_HOST="$try_host"
                        EXTERNAL_MONGO_PORT="$try_port"
                        MONGO_TLS_MODE="$try_tls"
                        MONGO_CONNECTED=true
                        break 4
                    fi
                done
            done
        done
    done

    if [ "$MONGO_CONNECTED" != "true" ]; then
        log_warning "MongoDB: All connection attempts failed after 3 rounds"
        log_warning "  Hosts tried: ${HOSTS_TO_TRY[*]}"
        log_warning "  Ports tried: ${PORTS_TO_TRY[*]}"
        log_warning "  TLS modes tried: off, on"
        attention_add "MongoDB" "ERROR" "Unable to connect to MongoDB at ${EXTERNAL_MONGO_HOST:-unknown}:${EXTERNAL_MONGO_PORT:-27017} — all host/port/TLS combinations failed after 3 rounds. Check connection credentials and network access."
        EXTERNAL_MONGO_STATUS="connection_failed"
        return 0
    fi

    log_success "MongoDB: Connected to $RESOLVED_MONGO_HOST:$EXTERNAL_MONGO_PORT (tls=${MONGO_TLS_MODE})"
    EXTERNAL_MONGO_STATUS="connected"

    # -----------------------------------------------------------------
    # Auto-detect DocumentDB engine via buildInfo
    # -----------------------------------------------------------------
    if [ -z "$EXTERNAL_MONGO_ENGINE" ]; then
        local engine_check
        engine_check=$($MONGO_CMD "$MONGO_URI" --quiet --eval '
            try {
                var bi = db.runCommand({buildInfo: 1});
                if (bi.modules && bi.modules.indexOf("enterprise") >= 0 && bi.version && /^4\.0\.0$/.test(bi.version)) { print("documentdb"); }
                else if (bi.ok && JSON.stringify(bi).indexOf("docdb") >= 0) { print("documentdb"); }
                else { print("mongodb"); }
            } catch(e) { print("mongodb"); }
        ' 2>/dev/null || echo "mongodb")
        if [ "$engine_check" = "documentdb" ]; then
            EXTERNAL_MONGO_ENGINE="documentdb"
            log_info "MongoDB: Detected DocumentDB engine - using retryWrites=false"
            # Rebuild URI with DocumentDB params
            MONGO_URI=$(build_mongo_uri "$RESOLVED_MONGO_HOST" "$EXTERNAL_MONGO_PORT" \
                "$EXTERNAL_MONGO_USER" "$EXTERNAL_MONGO_PASS" "admin" "$MONGO_TLS_MODE")
        fi
    fi

    # -----------------------------------------------------------------
    # Main collection: serverStatus, rs.status(), db.stats(), etc.
    # -----------------------------------------------------------------
    MONGO_RAW_DATA=$($MONGO_CMD "$MONGO_URI" --quiet --eval '
        var ss = db.serverStatus();
        var conn = ss.connections || {};
        var opLat = ss.opLatencies || {};
        var reads = opLat.reads || {};
        var writes = opLat.writes || {};
        var mem = ss.mem || {};
        var wt = (ss.wiredTiger || {}).cache || {};
        var gl = ss.globalLock || {};
        var queue = gl.currentQueue || {};

        // Replica set info
        var replStatus = null;
        try { replStatus = rs.status(); } catch(e) {}
        var memberCount = replStatus ? replStatus.members.length : 0;
        var healthyMembers = replStatus
            ? replStatus.members.filter(function(m) { return m.health === 1; }).length
            : 0;
        var hasPrimary = replStatus
            ? replStatus.members.some(function(m) { return m.stateStr === "PRIMARY"; })
            : false;
        var maxLag = 0;
        if (replStatus) {
            replStatus.members.forEach(function(m) {
                if (m.stateStr === "SECONDARY" && m.optimeDate) {
                    var lag = (new Date() - m.optimeDate) / 1000;
                    if (lag > maxLag) maxLag = lag;
                }
            });
        }

        var result = {
            version: ss.version,
            uptime: ss.uptime,
            conn_current: conn.current || 0,
            conn_available: conn.available || 0,
            read_latency_us: reads.latency || 0,
            read_ops: reads.ops || 0,
            write_latency_us: writes.latency || 0,
            write_ops: writes.ops || 0,
            mem_resident: mem.resident || 0,
            mem_virtual: mem.virtual || 0,
            cache_bytes_used: wt["bytes currently in the cache"] || 0,
            cache_bytes_max: wt["maximum bytes configured"] || 0,
            cache_dirty: wt["tracked dirty bytes in the cache"] || 0,
            queue_readers: queue.readers || 0,
            queue_writers: queue.writers || 0,
            is_replicaset: replStatus !== null,
            member_count: memberCount,
            healthy_members: healthyMembers,
            has_primary: hasPrimary,
            max_lag_seconds: maxLag
        };

        // Storage metrics via db.stats()
        try {
            var dbStats = db.stats();
            result.db_data_size = dbStats.dataSize || 0;
            result.db_storage_size = dbStats.storageSize || 0;
            result.db_index_size = dbStats.indexSize || 0;
            result.db_objects = dbStats.objects || 0;
            result.db_collections = dbStats.collections || 0;
            result.fs_total_size = dbStats.fsTotalSize || 0;
            result.fs_used_size = dbStats.fsUsedSize || 0;
            result.compression_savings_pct = dbStats.dataSize > 0
                ? Math.round((1 - dbStats.storageSize / dbStats.dataSize) * 100)
                : 0;
        } catch(e2) {
            result.db_data_size = 0;
            result.db_storage_size = 0;
            result.db_index_size = 0;
            result.db_objects = 0;
            result.db_collections = 0;
            result.fs_total_size = 0;
            result.fs_used_size = 0;
            result.compression_savings_pct = 0;
        }

        // All databases summary via adminCommand listDatabases
        try {
            var dbList = db.adminCommand({listDatabases: 1});
            result.total_disk_all_dbs = Number(dbList.totalSize) || 0;
            result.database_count = dbList.databases ? dbList.databases.length : 0;
        } catch(e3) {
            result.total_disk_all_dbs = 0;
            result.database_count = 0;
        }

        // Oplog stats
        try {
            var oplog = db.getSiblingDB("local").oplog.rs.stats();
            result.oplog_storage_size = oplog.storageSize || 0;
            result.oplog_max_size = oplog.maxSize || 0;
        } catch(e4) {
            result.oplog_storage_size = 0;
            result.oplog_max_size = 0;
        }

        // WiredTiger checkpoint latency
        var ckpt = (ss.wiredTiger || {}).checkpoint || {};
        result.checkpoint_last_duration_ms = Math.round(
            (ckpt["most recent time (usecs)"] || 0) / 1000
        );

        // Top 5 collections by size
        try {
            var topColls = [];
            db.getCollectionNames().forEach(function(c) {
                var s = db.getCollection(c).stats();
                topColls.push({
                    name: c,
                    storage_mb: Math.round((s.storageSize || 0) / 1048576),
                    index_mb: Math.round((s.totalIndexSize || 0) / 1048576),
                    count: s.count || 0
                });
            });
            topColls.sort(function(a, b) { return b.storage_mb - a.storage_mb; });
            result.top_collections = topColls.slice(0, 5);
        } catch(e5) {
            result.top_collections = [];
        }

        JSON.stringify(result);
    ' 2>/dev/null || echo '{}')

    if [ -z "$MONGO_RAW_DATA" ] || [ "$MONGO_RAW_DATA" = "{}" ]; then
        attention_add "MongoDB" "ERROR" "Unable to collect MongoDB metrics from ${RESOLVED_MONGO_HOST}:${EXTERNAL_MONGO_PORT} — serverStatus query returned empty. Check user permissions."
        EXTERNAL_MONGO_STATUS="error"
        return 0
    fi

    # -----------------------------------------------------------------
    # Per-database stats via listDatabases + db.stats()
    # -----------------------------------------------------------------
    MONGO_DATABASES_DATA=$($MONGO_CMD "$MONGO_URI" --quiet --eval '
        var results = [];
        try {
            var dbList = db.adminCommand({listDatabases: 1});
            (dbList.databases || []).forEach(function(d) {
                var dbObj = db.getSiblingDB(d.name);
                var st = {};
                try { st = dbObj.stats(); } catch(e) {}
                results.push({
                    name: d.name,
                    size_on_disk: Number(d.sizeOnDisk) || 0,
                    data_size: Number(st.dataSize) || 0,
                    storage_size: Number(st.storageSize) || 0,
                    index_size: Number(st.indexSize) || 0,
                    collections: Number(st.collections) || 0,
                    objects: Number(st.objects) || 0
                });
            });
        } catch(e) {}
        JSON.stringify(results);
    ' 2>/dev/null || echo '[]')

    # -----------------------------------------------------------------
    # All collections across non-system DBs with index details
    # -----------------------------------------------------------------
    MONGO_COLLECTIONS_DATA=$($MONGO_CMD "$MONGO_URI" --quiet --eval '
        var results = [];
        try {
            var dbList = db.adminCommand({listDatabases: 1});
            (dbList.databases || []).forEach(function(d) {
                if (d.name === "local" || d.name === "config") return;
                var dbObj = db.getSiblingDB(d.name);
                try {
                    dbObj.getCollectionNames().forEach(function(c) {
                        try {
                            var s = dbObj.getCollection(c).stats();
                            var idxDetails = [];
                            try {
                                dbObj.getCollection(c).getIndexes().forEach(function(idx) {
                                    var idxStats = null;
                                    try {
                                        var agg = dbObj.getCollection(c).aggregate(
                                            [{$indexStats:{}}]
                                        ).toArray();
                                        agg.forEach(function(is) {
                                            if (is.name === idx.name) idxStats = is;
                                        });
                                    } catch(ie) {}
                                    idxDetails.push({
                                        name: idx.name,
                                        key: JSON.stringify(idx.key),
                                        unique: idx.unique || false,
                                        sparse: idx.sparse || false,
                                        ttl: idx.expireAfterSeconds !== undefined
                                            ? idx.expireAfterSeconds : -1,
                                        size: 0,
                                        accesses: idxStats
                                            ? (idxStats.accesses
                                                ? Number(idxStats.accesses.ops) : 0)
                                            : 0,
                                        since: idxStats
                                            ? (idxStats.accesses
                                                ? idxStats.accesses.since.toISOString() : "")
                                            : ""
                                    });
                                });
                            } catch(ie2) {}
                            results.push({
                                db: d.name,
                                name: c,
                                storage_size: Number(s.storageSize) || 0,
                                data_size: Number(s.size) || 0,
                                index_size: Number(s.totalIndexSize) || 0,
                                count: Number(s.count) || 0,
                                avg_obj_size: Math.round(Number(s.avgObjSize) || 0),
                                nindexes: Number(s.nindexes) || 0,
                                capped: s.capped || false,
                                indexes: idxDetails
                            });
                        } catch(ce) {}
                    });
                } catch(de) {}
            });
        } catch(e) {}
        results.sort(function(a, b) { return b.storage_size - a.storage_size; });
        JSON.stringify(results);
    ' 2>/dev/null || echo '[]')

    log_success "MongoDB: Data collected"
}
