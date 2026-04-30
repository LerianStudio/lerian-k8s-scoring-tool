#!/bin/bash
# Output Orchestration — renders reports, creates compressed package

# Generate a complete K8s report for the current CURRENT_LANG
generate_full_report() {
    report_header
    report_health_dashboard
    report_nodes
    report_workloads
    report_security
    report_storage
    report_events
    report_networking
    report_config
    report_score_analysis

    # DB sections (only rendered if data was collected)
    if [ "$COLLECT_EXTERNAL_DBS" = "true" ]; then
        report_db_overview
        report_postgres
        report_mongodb
        report_valkey
        report_rabbitmq
        report_unified_score
    fi

    report_footer
}

# Backwards compat alias
generate_k8s_report() {
    generate_full_report
}

# Generate all 4 report files and package into tar.gz
generate_all_reports() {
    local output_dir
    output_dir=$(mktemp -d "${TMPDIR:-/tmp}/lerian-report-XXXXXX")

    log_info "Generating reports in $output_dir..."

    # Generate per-language reports
    local lang
    for lang in en pt-br es; do
        CURRENT_LANG="$lang"
        log_info "Generating ${lang} report..."
        generate_k8s_report > "${output_dir}/report_${lang}.md"
        log_success "report_${lang}.md generated"
    done

    # Generate combined multi-language report
    log_info "Generating combined multi-language report..."
    CURRENT_LANG="en"
    {
        # Combined frontmatter
        cat << EOF
---
title: Infrastructure Health Report (Multilingual)
generated: $(date '+%Y-%m-%dT%H:%M:%S%z')
cluster: $CLUSTER_NAME
kubernetes_version: $K8S_VERSION
target_namespaces: $TARGET_NAMESPACES
report_type: comprehensive_metrics_multilingual
languages: en, pt-BR, es
---

# Infrastructure Health Report / Relatório de Saúde da Infraestrutura / Informe de Salud de la Infraestructura

EOF
        # English section
        echo "## English"
        echo ""
        CURRENT_LANG="en"
        generate_k8s_report
        echo ""
        echo "---"
        echo ""

        # Portuguese section
        echo "## Português (Brasil)"
        echo ""
        CURRENT_LANG="pt-br"
        generate_k8s_report
        echo ""
        echo "---"
        echo ""

        # Spanish section
        echo "## Español"
        echo ""
        CURRENT_LANG="es"
        generate_k8s_report
    } > "${output_dir}/report_full.md"
    log_success "report_full.md generated"

    # Package into tar.gz
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local archive_name="${CLIENT_NAME}_${CLUSTER_NAME}_${timestamp}.tar.gz"
    # Remove characters that might cause issues in filenames
    archive_name=$(echo "$archive_name" | tr ' /' '_')

    # Generate attention report
    generate_attention_report "${output_dir}/attention.md"
    log_success "attention.md generated"

    log_info "Packaging reports into ${archive_name}..."

    # Use tar from the output directory
    (cd "$output_dir" && tar czf "${archive_name}" report_en.md report_pt-br.md report_es.md report_full.md attention.md)

    # Move archive to current directory
    mv "${output_dir}/${archive_name}" "./${archive_name}"

    # Point to the tar.gz for webhook upload
    REPORT_FULL_PATH="./${archive_name}"

    # Temp dir no longer needed — clean it up now
    rm -rf "$output_dir"

    log_success "Report package created: ${archive_name}"
    echo "$archive_name"
}

# Generate attention.md — issues encountered during execution
generate_attention_report() {
    local output_file="$1"

    {
        echo "---"
        echo "title: Attention Report — Issues During Collection"
        echo "generated: $(date '+%Y-%m-%dT%H:%M:%S%z')"
        echo "cluster: ${CLUSTER_NAME:-unknown}"
        echo "---"
        echo ""
        echo "# Attention Report"
        echo ""
        echo "> This file documents all warnings, errors, and issues encountered during"
        echo "> the infrastructure scoring collection. Review these items to understand"
        echo "> any gaps in the report data."
        echo ""

        if [ -z "$ATTENTION_LOG" ]; then
            echo "**No issues detected during collection.** All data sources were reachable and responsive."
        else
            echo "| Timestamp | Severity | Category | Details |"
            echo "|-----------|----------|----------|---------|"
            echo -n "$ATTENTION_LOG"
            echo ""
            echo "---"
            echo ""

            # Count by severity
            local error_count warning_count info_count
            error_count=$(printf '%s' "$ATTENTION_LOG" | grep -c "| ERROR |" 2>/dev/null || true)
            error_count="${error_count:-0}"
            warning_count=$(printf '%s' "$ATTENTION_LOG" | grep -c "| WARNING |" 2>/dev/null || true)
            warning_count="${warning_count:-0}"
            info_count=$(printf '%s' "$ATTENTION_LOG" | grep -c "| INFO |" 2>/dev/null || true)
            info_count="${info_count:-0}"
            echo "### Summary"
            echo ""
            echo "- **Errors:** ${error_count}"
            echo "- **Warnings:** ${warning_count}"
            echo "- **Info:** ${info_count}"
            echo ""

            if [ "$((error_count + 0))" -gt 0 ] 2>/dev/null; then
                echo "> **Impact:** Some data sources were unreachable. Scores for affected domains"
                echo "> are excluded from the Grand Unified Score to avoid inaccurate penalization."
            fi
        fi
    } > "$output_file"
}

# Main output function — called from lerian-scoring.sh
run_output() {
    local format="${1:-text}"
    local output_file="${2:-}"

    REPORT_FULL_PATH=""

    case "$format" in
        text)
            if [ -n "$output_file" ]; then
                # Single file output (default language = en)
                CURRENT_LANG="en"
                generate_k8s_report > "$output_file"
                log_success "Report saved to $output_file"
            else
                # Default: generate all 4 files + tar.gz
                generate_all_reports
            fi
            ;;
        json)
            # JSON output (placeholder for future)
            log_warning "JSON output not yet implemented in v2"
            CURRENT_LANG="en"
            generate_k8s_report
            ;;
        csv)
            # CSV output (placeholder for future)
            log_warning "CSV output not yet implemented in v2"
            CURRENT_LANG="en"
            generate_k8s_report
            ;;
    esac
}
