#!/bin/bash
# =============================================================================
# 31_webhook.sh - Report Upload via n8n Webhook
# =============================================================================
# Uploads the report_full.md file to an n8n webhook endpoint with metadata
# headers (environment, customer, file size).
#
# Compatibility: Bash 3.2+ (no associative arrays, no namerefs)
# =============================================================================

upload_report_webhook() {
    local report_file="$1"
    local webhook_url="${UPLOAD_WEBHOOK_URL:-}"

    if [ -z "$webhook_url" ]; then
        log_info "No webhook URL configured — skipping upload"
        return 0
    fi

    if [ -z "$report_file" ] || [ ! -f "$report_file" ]; then
        log_warning "Report file not found: ${report_file:-<empty>} — skipping upload"
        return 0
    fi

    if [ "$CURL_AVAILABLE" != "true" ]; then
        log_warning "curl not available — cannot upload report"
        return 0
    fi

    local file_size
    if [ "$(uname)" = "Darwin" ]; then
        file_size=$(stat -f%z "$report_file" 2>/dev/null || echo "0")
    else
        file_size=$(stat -c%s "$report_file" 2>/dev/null || echo "0")
    fi

    local filename
    filename=$(basename "$report_file")

    # Detect MIME type from file extension
    local mime_type="application/octet-stream"
    case "$filename" in
        *.tar.gz|*.tgz) mime_type="application/gzip" ;;
        *.gz)           mime_type="application/gzip" ;;
        *.md)           mime_type="text/markdown" ;;
        *.json)         mime_type="application/json" ;;
        *.csv)          mime_type="text/csv" ;;
        *.txt)          mime_type="text/plain" ;;
        *.pdf)          mime_type="application/pdf" ;;
        *.zip)          mime_type="application/zip" ;;
    esac

    log_info "Uploading report to webhook (${file_size} bytes, ${mime_type})..."

    local upload_result
    upload_result=$(curl --location -sf --max-time 120 \
        --header "filename: ${filename}" \
        --header "environment: ${ENVIRONMENT}" \
        --header "customer: ${CUSTOMER}" \
        --header "Content-Type: ${mime_type}" \
        --data-binary "@${report_file}" \
        "$webhook_url" 2>&1)

    if [ $? -eq 0 ]; then
        log_success "Report uploaded successfully"
    else
        log_warning "Report upload failed: ${upload_result}"
    fi
}
