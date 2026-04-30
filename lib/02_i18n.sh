#!/bin/bash
# i18n — Internationalization via function-per-key pattern
# Bash 3.2+ compatible (no associative arrays)
#
# Usage: lang_get "key_name"
# Set CURRENT_LANG before calling (en, pt-br, es). Defaults to en.

CURRENT_LANG="${CURRENT_LANG:-en}"

lang_get() {
    local key="$1"
    if type "_i18n_${key}" >/dev/null 2>&1; then
        "_i18n_${key}"
    else
        echo "[MISSING:${key}]"
    fi
}

# For multi-line strings (explanations, "What Good Looks Like" blocks)
lang_get_block() {
    local key="$1"
    if type "_i18n_block_${key}" >/dev/null 2>&1; then
        "_i18n_block_${key}"
    else
        echo "[MISSING_BLOCK:${key}]"
    fi
}

# ═══════════════════════════════════════════════════════════════════════
# TRANSLATED STRINGS (en, pt-br, es)
# ═══════════════════════════════════════════════════════════════════════

# ── Report Structure ──────────────────────────────────────────────────

_i18n_report_title() {
    case "$CURRENT_LANG" in
        pt-br) echo "Relatório de Métricas e Saúde do Cluster Kubernetes" ;;
        es)    echo "Informe de Métricas y Salud del Clúster Kubernetes" ;;
        *)     echo "Kubernetes Cluster Metrics & Health Report" ;;
    esac
}

_i18n_exec_summary() {
    case "$CURRENT_LANG" in
        pt-br) echo "Resumo Executivo" ;;
        es)    echo "Resumen Ejecutivo" ;;
        *)     echo "Executive Summary" ;;
    esac
}

_i18n_health_dashboard() {
    case "$CURRENT_LANG" in
        pt-br) echo "Painel de Pontuação de Saúde" ;;
        es)    echo "Panel de Puntuación de Salud" ;;
        *)     echo "Health Score Dashboard" ;;
    esac
}

_i18n_overall_health() {
    case "$CURRENT_LANG" in
        pt-br) echo "Saúde Geral do Cluster" ;;
        es)    echo "Salud General del Clúster" ;;
        *)     echo "Overall Cluster Health" ;;
    esac
}

_i18n_category_breakdown() {
    case "$CURRENT_LANG" in
        pt-br) echo "Detalhamento por Categoria" ;;
        es)    echo "Desglose por Categoría" ;;
        *)     echo "Category Breakdown" ;;
    esac
}

_i18n_score_interpretation() {
    case "$CURRENT_LANG" in
        pt-br) echo "Interpretação da Pontuação" ;;
        es)    echo "Interpretación de la Puntuación" ;;
        *)     echo "Score Interpretation" ;;
    esac
}

_i18n_report_complete() {
    case "$CURRENT_LANG" in
        pt-br) echo "GERAÇÃO DO RELATÓRIO CONCLUÍDA" ;;
        es)    echo "GENERACIÓN DEL INFORME COMPLETADA" ;;
        *)     echo "REPORT GENERATION COMPLETE" ;;
    esac
}

_i18n_report_metadata() {
    case "$CURRENT_LANG" in
        pt-br) echo "Metadados do Relatório" ;;
        es)    echo "Metadatos del Informe" ;;
        *)     echo "Report Metadata" ;;
    esac
}

# ── Category Names ────────────────────────────────────────────────────

_i18n_cat_nodes() {
    case "$CURRENT_LANG" in
        pt-br) echo "Saúde dos Nós" ;;
        es)    echo "Salud de los Nodos" ;;
        *)     echo "Nodes Health" ;;
    esac
}

_i18n_cat_workloads() {
    case "$CURRENT_LANG" in
        pt-br) echo "Saúde das Cargas de Trabalho" ;;
        es)    echo "Salud de las Cargas de Trabajo" ;;
        *)     echo "Workloads Health" ;;
    esac
}

_i18n_cat_resources() {
    case "$CURRENT_LANG" in
        pt-br) echo "Eficiência de Recursos" ;;
        es)    echo "Eficiencia de Recursos" ;;
        *)     echo "Resources Efficiency" ;;
    esac
}

_i18n_cat_storage() {
    case "$CURRENT_LANG" in
        pt-br) echo "Saúde do Armazenamento" ;;
        es)    echo "Salud del Almacenamiento" ;;
        *)     echo "Storage Health" ;;
    esac
}

_i18n_cat_security() {
    case "$CURRENT_LANG" in
        pt-br) echo "Segurança e RBAC" ;;
        es)    echo "Seguridad y RBAC" ;;
        *)     echo "Security & RBAC" ;;
    esac
}

_i18n_cat_events() {
    case "$CURRENT_LANG" in
        pt-br) echo "Análise de Eventos" ;;
        es)    echo "Análisis de Eventos" ;;
        *)     echo "Events Analysis" ;;
    esac
}

_i18n_cat_networking() {
    case "$CURRENT_LANG" in
        pt-br) echo "Rede" ;;
        es)    echo "Red" ;;
        *)     echo "Networking" ;;
    esac
}

_i18n_cat_config() {
    case "$CURRENT_LANG" in
        pt-br) echo "Melhores Práticas de Configuração" ;;
        es)    echo "Mejores Prácticas de Configuración" ;;
        *)     echo "Configuration Best Practices" ;;
    esac
}

# ── Rating Names ──────────────────────────────────────────────────────

_i18n_rating_excellent() {
    case "$CURRENT_LANG" in
        pt-br) echo "Excelente" ;;
        es)    echo "Excelente" ;;
        *)     echo "Excellent" ;;
    esac
}

_i18n_rating_good() {
    case "$CURRENT_LANG" in
        pt-br) echo "Bom" ;;
        es)    echo "Bueno" ;;
        *)     echo "Good" ;;
    esac
}

_i18n_rating_fair() {
    case "$CURRENT_LANG" in
        pt-br) echo "Regular" ;;
        es)    echo "Regular" ;;
        *)     echo "Fair" ;;
    esac
}

_i18n_rating_poor() {
    case "$CURRENT_LANG" in
        pt-br) echo "Ruim" ;;
        es)    echo "Deficiente" ;;
        *)     echo "Poor" ;;
    esac
}

_i18n_rating_critical() {
    case "$CURRENT_LANG" in
        pt-br) echo "Crítico" ;;
        es)    echo "Crítico" ;;
        *)     echo "Critical" ;;
    esac
}

# ── Section Headers ───────────────────────────────────────────────────

_i18n_node_infrastructure() {
    case "$CURRENT_LANG" in
        pt-br) echo "Infraestrutura de Nós" ;;
        es)    echo "Infraestructura de Nodos" ;;
        *)     echo "Node Infrastructure" ;;
    esac
}

_i18n_node_summary() {
    case "$CURRENT_LANG" in
        pt-br) echo "Resumo dos Nós" ;;
        es)    echo "Resumen de Nodos" ;;
        *)     echo "Node Summary" ;;
    esac
}

_i18n_node_capacity() {
    case "$CURRENT_LANG" in
        pt-br) echo "Detalhes de Capacidade dos Nós" ;;
        es)    echo "Detalles de Capacidad de los Nodos" ;;
        *)     echo "Node Capacity Details" ;;
    esac
}

_i18n_workload_metrics() {
    case "$CURRENT_LANG" in
        pt-br) echo "Métricas de Carga de Trabalho" ;;
        es)    echo "Métricas de Carga de Trabajo" ;;
        *)     echo "Workload Metrics" ;;
    esac
}

_i18n_pod_usage() {
    case "$CURRENT_LANG" in
        pt-br) echo "Uso de Recursos dos Pods" ;;
        es)    echo "Uso de Recursos de los Pods" ;;
        *)     echo "Pod Resource Usage" ;;
    esac
}

_i18n_deployment_status() {
    case "$CURRENT_LANG" in
        pt-br) echo "Status dos Deployments" ;;
        es)    echo "Estado de los Deployments" ;;
        *)     echo "Deployment Status" ;;
    esac
}

_i18n_resource_requests() {
    case "$CURRENT_LANG" in
        pt-br) echo "Requests e Limits de Recursos" ;;
        es)    echo "Requests y Limits de Recursos" ;;
        *)     echo "Resource Requests & Limits" ;;
    esac
}

_i18n_security_rbac() {
    case "$CURRENT_LANG" in
        pt-br) echo "Segurança e RBAC" ;;
        es)    echo "Seguridad y RBAC" ;;
        *)     echo "Security & RBAC" ;;
    esac
}

_i18n_storage_section() {
    case "$CURRENT_LANG" in
        pt-br) echo "Recursos de Armazenamento" ;;
        es)    echo "Recursos de Almacenamiento" ;;
        *)     echo "Storage Resources" ;;
    esac
}

_i18n_events_section() {
    case "$CURRENT_LANG" in
        pt-br) echo "Eventos e Monitoramento" ;;
        es)    echo "Eventos y Monitoreo" ;;
        *)     echo "Events & Monitoring" ;;
    esac
}

_i18n_networking_section() {
    case "$CURRENT_LANG" in
        pt-br) echo "Rede" ;;
        es)    echo "Red" ;;
        *)     echo "Networking" ;;
    esac
}

_i18n_config_section() {
    case "$CURRENT_LANG" in
        pt-br) echo "Melhores Práticas de Configuração" ;;
        es)    echo "Mejores Prácticas de Configuración" ;;
        *)     echo "Configuration Best Practices" ;;
    esac
}

_i18n_score_analysis() {
    case "$CURRENT_LANG" in
        pt-br) echo "Análise de Pontuação" ;;
        es)    echo "Análisis de Puntuación" ;;
        *)     echo "Score Analysis" ;;
    esac
}

_i18n_top_priorities() {
    case "$CURRENT_LANG" in
        pt-br) echo "Principais Melhorias Prioritárias" ;;
        es)    echo "Mejoras Prioritarias Principales" ;;
        *)     echo "Top Priority Improvements" ;;
    esac
}

_i18n_db_health_scoring() {
    case "$CURRENT_LANG" in
        pt-br) echo "Pontuação de Saúde de Bancos de Dados Externos" ;;
        es)    echo "Puntuación de Salud de Bases de Datos Externas" ;;
        *)     echo "External Database Health Scoring" ;;
    esac
}

_i18n_db_overview() {
    case "$CURRENT_LANG" in
        pt-br) echo "Visão Geral da Saúde dos Bancos de Dados" ;;
        es)    echo "Visión General de Salud de las Bases de Datos" ;;
        *)     echo "Database Health Overview" ;;
    esac
}

# ── Table Headers ─────────────────────────────────────────────────────

_i18n_th_metric() {
    case "$CURRENT_LANG" in
        pt-br) echo "Métrica" ;;
        es)    echo "Métrica" ;;
        *)     echo "Metric" ;;
    esac
}

_i18n_th_value() {
    case "$CURRENT_LANG" in
        pt-br) echo "Valor" ;;
        es)    echo "Valor" ;;
        *)     echo "Value" ;;
    esac
}

_i18n_th_status() {
    case "$CURRENT_LANG" in
        pt-br) echo "Status" ;;
        es)    echo "Estado" ;;
        *)     echo "Status" ;;
    esac
}

_i18n_th_node_name() {
    case "$CURRENT_LANG" in
        pt-br) echo "Nome do Nó" ;;
        es)    echo "Nombre del Nodo" ;;
        *)     echo "Node Name" ;;
    esac
}

_i18n_th_cpu_cores() {
    case "$CURRENT_LANG" in
        pt-br) echo "CPU (cores)" ;;
        es)    echo "CPU (cores)" ;;
        *)     echo "CPU (cores)" ;;
    esac
}

_i18n_th_cpu_pct() {
    case "$CURRENT_LANG" in
        pt-br) echo "CPU (%)" ;;
        es)    echo "CPU (%)" ;;
        *)     echo "CPU (%)" ;;
    esac
}

_i18n_th_mem_bytes() {
    case "$CURRENT_LANG" in
        pt-br) echo "Memória (bytes)" ;;
        es)    echo "Memoria (bytes)" ;;
        *)     echo "Memory (bytes)" ;;
    esac
}

_i18n_th_mem_pct() {
    case "$CURRENT_LANG" in
        pt-br) echo "Memória (%)" ;;
        es)    echo "Memoria (%)" ;;
        *)     echo "Memory (%)" ;;
    esac
}

_i18n_th_namespace() {
    case "$CURRENT_LANG" in
        pt-br) echo "Namespace" ;;
        es)    echo "Namespace" ;;
        *)     echo "Namespace" ;;
    esac
}

_i18n_th_pod_name() {
    case "$CURRENT_LANG" in
        pt-br) echo "Nome do Pod" ;;
        es)    echo "Nombre del Pod" ;;
        *)     echo "Pod Name" ;;
    esac
}

_i18n_th_deploy_name() {
    case "$CURRENT_LANG" in
        pt-br) echo "Deployment" ;;
        es)    echo "Deployment" ;;
        *)     echo "Deployment" ;;
    esac
}

_i18n_th_replicas() {
    case "$CURRENT_LANG" in
        pt-br) echo "Réplicas" ;;
        es)    echo "Réplicas" ;;
        *)     echo "Replicas" ;;
    esac
}

_i18n_th_ready() {
    case "$CURRENT_LANG" in
        pt-br) echo "Prontos" ;;
        es)    echo "Listos" ;;
        *)     echo "Ready" ;;
    esac
}

_i18n_th_available() {
    case "$CURRENT_LANG" in
        pt-br) echo "Disponíveis" ;;
        es)    echo "Disponibles" ;;
        *)     echo "Available" ;;
    esac
}

_i18n_th_category() {
    case "$CURRENT_LANG" in
        pt-br) echo "Categoria" ;;
        es)    echo "Categoría" ;;
        *)     echo "Category" ;;
    esac
}

_i18n_th_score() {
    case "$CURRENT_LANG" in
        pt-br) echo "Pontuação" ;;
        es)    echo "Puntuación" ;;
        *)     echo "Score" ;;
    esac
}

_i18n_th_weight() {
    case "$CURRENT_LANG" in
        pt-br) echo "Peso" ;;
        es)    echo "Peso" ;;
        *)     echo "Weight" ;;
    esac
}

_i18n_th_rating() {
    case "$CURRENT_LANG" in
        pt-br) echo "Classificação" ;;
        es)    echo "Clasificación" ;;
        *)     echo "Rating" ;;
    esac
}

_i18n_th_cpu_capacity() {
    case "$CURRENT_LANG" in
        pt-br) echo "Capacidade de CPU" ;;
        es)    echo "Capacidad de CPU" ;;
        *)     echo "CPU Capacity" ;;
    esac
}

_i18n_th_cpu_allocatable() {
    case "$CURRENT_LANG" in
        pt-br) echo "CPU Alocável" ;;
        es)    echo "CPU Asignable" ;;
        *)     echo "CPU Allocatable" ;;
    esac
}

_i18n_th_mem_capacity() {
    case "$CURRENT_LANG" in
        pt-br) echo "Capacidade de Memória" ;;
        es)    echo "Capacidad de Memoria" ;;
        *)     echo "Memory Capacity" ;;
    esac
}

_i18n_th_mem_allocatable() {
    case "$CURRENT_LANG" in
        pt-br) echo "Memória Alocável" ;;
        es)    echo "Memoria Asignable" ;;
        *)     echo "Memory Allocatable" ;;
    esac
}

_i18n_th_cpu_request() {
    case "$CURRENT_LANG" in
        pt-br) echo "CPU Request" ;;
        es)    echo "CPU Request" ;;
        *)     echo "CPU Request" ;;
    esac
}

_i18n_th_cpu_limit() {
    case "$CURRENT_LANG" in
        pt-br) echo "CPU Limit" ;;
        es)    echo "CPU Limit" ;;
        *)     echo "CPU Limit" ;;
    esac
}

_i18n_th_mem_request() {
    case "$CURRENT_LANG" in
        pt-br) echo "Memory Request" ;;
        es)    echo "Memory Request" ;;
        *)     echo "Memory Request" ;;
    esac
}

_i18n_th_mem_limit() {
    case "$CURRENT_LANG" in
        pt-br) echo "Memory Limit" ;;
        es)    echo "Memory Limit" ;;
        *)     echo "Memory Limit" ;;
    esac
}

_i18n_th_property() {
    case "$CURRENT_LANG" in
        pt-br) echo "Propriedade" ;;
        es)    echo "Propiedad" ;;
        *)     echo "Property" ;;
    esac
}

_i18n_th_database() {
    case "$CURRENT_LANG" in
        pt-br) echo "Banco de Dados" ;;
        es)    echo "Base de Datos" ;;
        *)     echo "Database" ;;
    esac
}

_i18n_th_domain() {
    case "$CURRENT_LANG" in
        pt-br) echo "Domínio" ;;
        es)    echo "Dominio" ;;
        *)     echo "Domain" ;;
    esac
}

_i18n_th_weighted() {
    case "$CURRENT_LANG" in
        pt-br) echo "Ponderado" ;;
        es)    echo "Ponderado" ;;
        *)     echo "Weighted" ;;
    esac
}

_i18n_th_table() {
    case "$CURRENT_LANG" in
        pt-br) echo "Tabela" ;;
        es)    echo "Tabla" ;;
        *)     echo "Table" ;;
    esac
}

_i18n_th_total_size() {
    case "$CURRENT_LANG" in
        pt-br) echo "Tamanho Total" ;;
        es)    echo "Tamaño Total" ;;
        *)     echo "Total Size" ;;
    esac
}

_i18n_th_dead_tuples() {
    case "$CURRENT_LANG" in
        pt-br) echo "Tuplas Mortas %" ;;
        es)    echo "Tuplas Muertas %" ;;
        *)     echo "Dead Tuples %" ;;
    esac
}

_i18n_th_component() {
    case "$CURRENT_LANG" in
        pt-br) echo "Componente" ;;
        es)    echo "Componente" ;;
        *)     echo "Component" ;;
    esac
}

_i18n_th_size() {
    case "$CURRENT_LANG" in
        pt-br) echo "Tamanho" ;;
        es)    echo "Tamaño" ;;
        *)     echo "Size" ;;
    esac
}

_i18n_th_queue() {
    case "$CURRENT_LANG" in
        pt-br) echo "Fila" ;;
        es)    echo "Cola" ;;
        *)     echo "Queue" ;;
    esac
}

_i18n_th_messages() {
    case "$CURRENT_LANG" in
        pt-br) echo "Mensagens" ;;
        es)    echo "Mensajes" ;;
        *)     echo "Messages" ;;
    esac
}

_i18n_th_consumers() {
    case "$CURRENT_LANG" in
        pt-br) echo "Consumidores" ;;
        es)    echo "Consumidores" ;;
        *)     echo "Consumers" ;;
    esac
}

_i18n_th_state() {
    case "$CURRENT_LANG" in
        pt-br) echo "Estado" ;;
        es)    echo "Estado" ;;
        *)     echo "State" ;;
    esac
}

_i18n_th_node() {
    case "$CURRENT_LANG" in
        pt-br) echo "Nó" ;;
        es)    echo "Nodo" ;;
        *)     echo "Node" ;;
    esac
}

_i18n_th_memory_used() {
    case "$CURRENT_LANG" in
        pt-br) echo "Memória Utilizada" ;;
        es)    echo "Memoria Utilizada" ;;
        *)     echo "Memory Used" ;;
    esac
}

_i18n_th_memory_limit() {
    case "$CURRENT_LANG" in
        pt-br) echo "Limite de Memória" ;;
        es)    echo "Límite de Memoria" ;;
        *)     echo "Memory Limit" ;;
    esac
}

_i18n_th_disk_free() {
    case "$CURRENT_LANG" in
        pt-br) echo "Disco Livre" ;;
        es)    echo "Disco Libre" ;;
        *)     echo "Disk Free" ;;
    esac
}

_i18n_th_fd_used_limit() {
    case "$CURRENT_LANG" in
        pt-br) echo "FD Usado/Limite" ;;
        es)    echo "FD Usado/Límite" ;;
        *)     echo "FD Used/Limit" ;;
    esac
}

_i18n_th_running() {
    case "$CURRENT_LANG" in
        pt-br) echo "Executando" ;;
        es)    echo "Ejecutando" ;;
        *)     echo "Running" ;;
    esac
}

_i18n_th_hosts() {
    case "$CURRENT_LANG" in
        pt-br) echo "Hosts" ;;
        es)    echo "Hosts" ;;
        *)     echo "Hosts" ;;
    esac
}

_i18n_th_type() {
    case "$CURRENT_LANG" in
        pt-br) echo "Tipo" ;;
        es)    echo "Tipo" ;;
        *)     echo "Type" ;;
    esac
}

_i18n_th_cluster_ip() {
    case "$CURRENT_LANG" in
        pt-br) echo "IP do Cluster" ;;
        es)    echo "IP del Cluster" ;;
        *)     echo "Cluster IP" ;;
    esac
}

_i18n_th_ports() {
    case "$CURRENT_LANG" in
        pt-br) echo "Portas" ;;
        es)    echo "Puertos" ;;
        *)     echo "Ports" ;;
    esac
}

_i18n_th_tls() {
    case "$CURRENT_LANG" in
        pt-br) echo "TLS" ;;
        es)    echo "TLS" ;;
        *)     echo "TLS" ;;
    esac
}

_i18n_th_provisioner() {
    case "$CURRENT_LANG" in
        pt-br) echo "Provisionador" ;;
        es)    echo "Proveedor" ;;
        *)     echo "Provisioner" ;;
    esac
}

_i18n_th_reclaim_policy() {
    case "$CURRENT_LANG" in
        pt-br) echo "Política de Recuperação" ;;
        es)    echo "Política de Recuperación" ;;
        *)     echo "Reclaim Policy" ;;
    esac
}

_i18n_th_default() {
    case "$CURRENT_LANG" in
        pt-br) echo "Padrão" ;;
        es)    echo "Predeterminado" ;;
        *)     echo "Default" ;;
    esac
}

_i18n_th_reason() {
    case "$CURRENT_LANG" in
        pt-br) echo "Razão" ;;
        es)    echo "Razón" ;;
        *)     echo "Reason" ;;
    esac
}

_i18n_th_message() {
    case "$CURRENT_LANG" in
        pt-br) echo "Mensagem" ;;
        es)    echo "Mensaje" ;;
        *)     echo "Message" ;;
    esac
}

_i18n_th_count() {
    case "$CURRENT_LANG" in
        pt-br) echo "Contagem" ;;
        es)    echo "Cantidad" ;;
        *)     echo "Count" ;;
    esac
}

_i18n_th_last_seen() {
    case "$CURRENT_LANG" in
        pt-br) echo "Última Vez" ;;
        es)    echo "Última Vez" ;;
        *)     echo "Last Seen" ;;
    esac
}

_i18n_th_container() {
    case "$CURRENT_LANG" in
        pt-br) echo "Container" ;;
        es)    echo "Contenedor" ;;
        *)     echo "Container" ;;
    esac
}

_i18n_th_name() {
    case "$CURRENT_LANG" in
        pt-br) echo "Nome" ;;
        es)    echo "Nombre" ;;
        *)     echo "Name" ;;
    esac
}

_i18n_th_capacity() {
    case "$CURRENT_LANG" in
        pt-br) echo "Capacidade" ;;
        es)    echo "Capacidad" ;;
        *)     echo "Capacity" ;;
    esac
}

_i18n_th_storage_class() {
    case "$CURRENT_LANG" in
        pt-br) echo "Classe de Armazenamento" ;;
        es)    echo "Clase de Almacenamiento" ;;
        *)     echo "Storage Class" ;;
    esac
}

_i18n_status_disconnected() {
    case "$CURRENT_LANG" in
        pt-br) echo "Desconectado" ;;
        es)    echo "Desconectado" ;;
        *)     echo "Disconnected" ;;
    esac
}

_i18n_status_not_configured() {
    case "$CURRENT_LANG" in
        pt-br) echo "Não Configurado" ;;
        es)    echo "No Configurado" ;;
        *)     echo "Not Configured" ;;
    esac
}

_i18n_status_skipped() {
    case "$CURRENT_LANG" in
        pt-br) echo "Ignorado" ;;
        es)    echo "Omitido" ;;
        *)     echo "Skipped" ;;
    esac
}

_i18n_th_overall_score() {
    case "$CURRENT_LANG" in
        pt-br) echo "Pontuação Geral" ;;
        es)    echo "Puntuación General" ;;
        *)     echo "Overall Score" ;;
    esac
}

_i18n_th_version() {
    case "$CURRENT_LANG" in
        pt-br) echo "Versão" ;;
        es)    echo "Versión" ;;
        *)     echo "Version" ;;
    esac
}

_i18n_grand_total() {
    case "$CURRENT_LANG" in
        pt-br) echo "Total Geral" ;;
        es)    echo "Total General" ;;
        *)     echo "Grand Total" ;;
    esac
}

_i18n_overall_pg_score() {
    case "$CURRENT_LANG" in
        pt-br) echo "Pontuação Geral do PostgreSQL:" ;;
        es)    echo "Puntuación General de PostgreSQL:" ;;
        *)     echo "Overall PostgreSQL Score:" ;;
    esac
}

_i18n_overall_mongo_score() {
    case "$CURRENT_LANG" in
        pt-br) echo "Pontuação Geral do MongoDB:" ;;
        es)    echo "Puntuación General de MongoDB:" ;;
        *)     echo "Overall MongoDB Score:" ;;
    esac
}

_i18n_overall_valkey_score() {
    case "$CURRENT_LANG" in
        pt-br) echo "Pontuação Geral do Valkey/Redis:" ;;
        es)    echo "Puntuación General de Valkey/Redis:" ;;
        *)     echo "Overall Valkey/Redis Score:" ;;
    esac
}

_i18n_overall_rmq_score() {
    case "$CURRENT_LANG" in
        pt-br) echo "Pontuação Geral do RabbitMQ:" ;;
        es)    echo "Puntuación General de RabbitMQ:" ;;
        *)     echo "Overall RabbitMQ Score:" ;;
    esac
}

_i18n_grand_unified_label() {
    case "$CURRENT_LANG" in
        pt-br) echo "Pontuação Unificada:" ;;
        es)    echo "Puntuación Unificada:" ;;
        *)     echo "Grand Unified Score:" ;;
    esac
}

# ── DB Category Names ────────────────────────────────────────────────

_i18n_cat_performance() {
    case "$CURRENT_LANG" in
        pt-br) echo "Desempenho" ;;
        es)    echo "Rendimiento" ;;
        *)     echo "Performance" ;;
    esac
}

_i18n_cat_availability() {
    case "$CURRENT_LANG" in
        pt-br) echo "Disponibilidade e Conexões" ;;
        es)    echo "Disponibilidad y Conexiones" ;;
        *)     echo "Availability & Connections" ;;
    esac
}

_i18n_cat_maintenance() {
    case "$CURRENT_LANG" in
        pt-br) echo "Manutenção" ;;
        es)    echo "Mantenimiento" ;;
        *)     echo "Maintenance" ;;
    esac
}

_i18n_cat_replication() {
    case "$CURRENT_LANG" in
        pt-br) echo "Replicação e Backup" ;;
        es)    echo "Replicación y Backup" ;;
        *)     echo "Replication & Backup" ;;
    esac
}

_i18n_cat_resource_util() {
    case "$CURRENT_LANG" in
        pt-br) echo "Utilização de Recursos" ;;
        es)    echo "Utilización de Recursos" ;;
        *)     echo "Resource Utilization" ;;
    esac
}

_i18n_cat_io() {
    case "$CURRENT_LANG" in
        pt-br) echo "I/O & IOPS" ;;
        es)    echo "I/O & IOPS" ;;
        *)     echo "I/O & IOPS" ;;
    esac
}

_i18n_cat_index_health() {
    case "$CURRENT_LANG" in
        pt-br) echo "Saúde dos Índices" ;;
        es)    echo "Salud de los Índices" ;;
        *)     echo "Index Health" ;;
    esac
}

_i18n_cat_configuration() {
    case "$CURRENT_LANG" in
        pt-br) echo "Configuração" ;;
        es)    echo "Configuración" ;;
        *)     echo "Configuration" ;;
    esac
}

_i18n_cat_mongo_replication() {
    case "$CURRENT_LANG" in
        pt-br) echo "Replicação" ;;
        es)    echo "Replicación" ;;
        *)     echo "Replication" ;;
    esac
}

_i18n_cat_mongo_storage() {
    case "$CURRENT_LANG" in
        pt-br) echo "Armazenamento & WT" ;;
        es)    echo "Almacenamiento & WT" ;;
        *)     echo "Storage & WT" ;;
    esac
}

_i18n_cat_cluster_topology() {
    case "$CURRENT_LANG" in
        pt-br) echo "Topologia do Cluster" ;;
        es)    echo "Topología del Cluster" ;;
        *)     echo "Cluster Topology" ;;
    esac
}

_i18n_cat_memory_mgmt() {
    case "$CURRENT_LANG" in
        pt-br) echo "Gestão de Memória" ;;
        es)    echo "Gestión de Memoria" ;;
        *)     echo "Memory Management" ;;
    esac
}

_i18n_cat_persistence() {
    case "$CURRENT_LANG" in
        pt-br) echo "Persistência" ;;
        es)    echo "Persistencia" ;;
        *)     echo "Persistence" ;;
    esac
}

_i18n_cat_cluster_health() {
    case "$CURRENT_LANG" in
        pt-br) echo "Saúde do Cluster" ;;
        es)    echo "Salud del Cluster" ;;
        *)     echo "Cluster Health" ;;
    esac
}

_i18n_cat_queue_health() {
    case "$CURRENT_LANG" in
        pt-br) echo "Saúde das Filas" ;;
        es)    echo "Salud de las Colas" ;;
        *)     echo "Queue Health" ;;
    esac
}

_i18n_cat_message_flow() {
    case "$CURRENT_LANG" in
        pt-br) echo "Fluxo de Mensagens" ;;
        es)    echo "Flujo de Mensajes" ;;
        *)     echo "Message Flow" ;;
    esac
}

_i18n_cat_node_resources() {
    case "$CURRENT_LANG" in
        pt-br) echo "Recursos do Nó" ;;
        es)    echo "Recursos del Nodo" ;;
        *)     echo "Node Resources" ;;
    esac
}

_i18n_cat_connections() {
    case "$CURRENT_LANG" in
        pt-br) echo "Conexões" ;;
        es)    echo "Conexiones" ;;
        *)     echo "Connections" ;;
    esac
}

_i18n_cat_db_security() {
    case "$CURRENT_LANG" in
        pt-br) echo "Segurança" ;;
        es)    echo "Seguridad" ;;
        *)     echo "Security" ;;
    esac
}

_i18n_cat_mongo_resources() {
    case "$CURRENT_LANG" in
        pt-br) echo "Recursos" ;;
        es)    echo "Recursos" ;;
        *)     echo "Resources" ;;
    esac
}

# ── Unified Score Interpretation ─────────────────────────────────────

_i18n_unified_excellent() {
    case "$CURRENT_LANG" in
        pt-br) echo "Sua infraestrutura está bem configurada, monitorada e mantida. Continue as práticas atuais e foque na otimização." ;;
        es)    echo "Su infraestructura está bien configurada, monitoreada y mantenida. Continúe las prácticas actuales y enfóquese en la optimización." ;;
        *)     echo "Your infrastructure is well-configured, monitored, and maintained. Continue current practices and focus on optimization." ;;
    esac
}

_i18n_unified_good() {
    case "$CURRENT_LANG" in
        pt-br) echo "A infraestrutura está saudável com pequenas áreas para melhoria. Revise categorias com pontuação abaixo de 75 para melhorias direcionadas." ;;
        es)    echo "La infraestructura está saludable con áreas menores para mejora. Revise las categorías con puntuación inferior a 75 para mejoras dirigidas." ;;
        *)     echo "Infrastructure is healthy with minor areas for improvement. Review categories scoring below 75 for targeted enhancements." ;;
    esac
}

_i18n_unified_fair() {
    case "$CURRENT_LANG" in
        pt-br) echo "Várias áreas precisam de atenção. Priorize categorias com pontuação abaixo de 60 e aborde as descobertas críticas primeiro." ;;
        es)    echo "Varias áreas necesitan atención. Priorice las categorías con puntuación inferior a 60 y aborde los hallazgos críticos primero." ;;
        *)     echo "Several areas need attention. Prioritize categories scoring below 60 and address critical findings first." ;;
    esac
}

_i18n_unified_poor() {
    case "$CURRENT_LANG" in
        pt-br) echo "Riscos significativos de infraestrutura detectados. Ação imediata recomendada nas categorias com pontuação baixa." ;;
        es)    echo "Riesgos significativos de infraestructura detectados. Acción inmediata recomendada en las categorías con puntuación baja." ;;
        *)     echo "Significant infrastructure risks detected. Immediate action recommended on low-scoring categories." ;;
    esac
}

_i18n_unified_critical() {
    case "$CURRENT_LANG" in
        pt-br) echo "A infraestrutura está em risco. Aborde as descobertas críticas imediatamente, particularmente em domínios com pontuação abaixo de 40." ;;
        es)    echo "La infraestructura está en riesgo. Aborde los hallazgos críticos inmediatamente, particularmente en dominios con puntuación inferior a 40." ;;
        *)     echo "Infrastructure is at risk. Address critical findings immediately, particularly in any domain scoring below 40." ;;
    esac
}

# ── Status Labels ─────────────────────────────────────────────────────

_i18n_status_ready() {
    case "$CURRENT_LANG" in
        pt-br) echo "Pronto" ;;
        es)    echo "Listo" ;;
        *)     echo "Ready" ;;
    esac
}

_i18n_status_not_ready() {
    case "$CURRENT_LANG" in
        pt-br) echo "NãoPronto" ;;
        es)    echo "NoListo" ;;
        *)     echo "NotReady" ;;
    esac
}

_i18n_status_healthy() {
    case "$CURRENT_LANG" in
        pt-br) echo "Saudável" ;;
        es)    echo "Saludable" ;;
        *)     echo "Healthy" ;;
    esac
}

_i18n_status_degraded() {
    case "$CURRENT_LANG" in
        pt-br) echo "Degradado" ;;
        es)    echo "Degradado" ;;
        *)     echo "Degraded" ;;
    esac
}

_i18n_status_running() {
    case "$CURRENT_LANG" in
        pt-br) echo "Em Execução" ;;
        es)    echo "En Ejecución" ;;
        *)     echo "Running" ;;
    esac
}

_i18n_status_pending() {
    case "$CURRENT_LANG" in
        pt-br) echo "Pendente" ;;
        es)    echo "Pendiente" ;;
        *)     echo "Pending" ;;
    esac
}

_i18n_status_failed() {
    case "$CURRENT_LANG" in
        pt-br) echo "Falhou" ;;
        es)    echo "Fallido" ;;
        *)     echo "Failed" ;;
    esac
}

_i18n_status_connected() {
    case "$CURRENT_LANG" in
        pt-br) echo "Conectado" ;;
        es)    echo "Conectado" ;;
        *)     echo "Connected" ;;
    esac
}

_i18n_status_unavailable() {
    case "$CURRENT_LANG" in
        pt-br) echo "Indisponível" ;;
        es)    echo "No Disponible" ;;
        *)     echo "Unavailable" ;;
    esac
}

# ── Inline Status Labels (DB metrics tables) ────────────────────────

_i18n_status_ok() {
    case "$CURRENT_LANG" in
        pt-br) echo "OK" ;;
        es)    echo "OK" ;;
        *)     echo "OK" ;;
    esac
}

_i18n_status_low() {
    case "$CURRENT_LANG" in
        pt-br) echo "Baixo" ;;
        es)    echo "Bajo" ;;
        *)     echo "Low" ;;
    esac
}

_i18n_status_none() {
    case "$CURRENT_LANG" in
        pt-br) echo "Nenhum" ;;
        es)    echo "Ninguno" ;;
        *)     echo "None" ;;
    esac
}

_i18n_status_warning() {
    case "$CURRENT_LANG" in
        pt-br) echo "Alerta" ;;
        es)    echo "Advertencia" ;;
        *)     echo "Warning" ;;
    esac
}

_i18n_status_critical() {
    case "$CURRENT_LANG" in
        pt-br) echo "Crítico" ;;
        es)    echo "Crítico" ;;
        *)     echo "Critical" ;;
    esac
}

_i18n_status_clean() {
    case "$CURRENT_LANG" in
        pt-br) echo "Limpo" ;;
        es)    echo "Limpio" ;;
        *)     echo "Clean" ;;
    esac
}

_i18n_status_no_limit() {
    case "$CURRENT_LANG" in
        pt-br) echo "Sem limite" ;;
        es)    echo "Sin límite" ;;
        *)     echo "No limit" ;;
    esac
}

_i18n_status_high_frag() {
    case "$CURRENT_LANG" in
        pt-br) echo "Alta fragmentação" ;;
        es)    echo "Alta fragmentación" ;;
        *)     echo "High fragmentation" ;;
    esac
}

_i18n_status_no_maxmemory() {
    case "$CURRENT_LANG" in
        pt-br) echo "sem maxmemory definido" ;;
        es)    echo "sin maxmemory configurado" ;;
        *)     echo "no maxmemory set" ;;
    esac
}

_i18n_status_high() {
    case "$CURRENT_LANG" in
        pt-br) echo "Alto" ;;
        es)    echo "Alto" ;;
        *)     echo "High" ;;
    esac
}

_i18n_status_elevated() {
    case "$CURRENT_LANG" in
        pt-br) echo "Elevado" ;;
        es)    echo "Elevado" ;;
        *)     echo "Elevated" ;;
    esac
}

_i18n_status_using_swap() {
    case "$CURRENT_LANG" in
        pt-br) echo "Usando swap" ;;
        es)    echo "Usando swap" ;;
        *)     echo "Using swap" ;;
    esac
}

_i18n_status_evictions_occurring() {
    case "$CURRENT_LANG" in
        pt-br) echo "Evicções ocorrendo" ;;
        es)    echo "Desalojos ocurriendo" ;;
        *)     echo "Evictions occurring" ;;
    esac
}

_i18n_status_many_slow_queries() {
    case "$CURRENT_LANG" in
        pt-br) echo "Muitas consultas lentas" ;;
        es)    echo "Muchas consultas lentas" ;;
        *)     echo "Many slow queries" ;;
    esac
}

_i18n_status_some_slow_queries() {
    case "$CURRENT_LANG" in
        pt-br) echo "Algumas consultas lentas" ;;
        es)    echo "Algunas consultas lentas" ;;
        *)     echo "Some slow queries" ;;
    esac
}

_i18n_status_few_slow_queries() {
    case "$CURRENT_LANG" in
        pt-br) echo "Poucas consultas lentas" ;;
        es)    echo "Pocas consultas lentas" ;;
        *)     echo "Few slow queries" ;;
    esac
}

_i18n_status_critical_backlog() {
    case "$CURRENT_LANG" in
        pt-br) echo "Backlog crítico" ;;
        es)    echo "Backlog crítico" ;;
        *)     echo "Critical backlog" ;;
    esac
}

# ── DB Metric Labels (left column of Key Metrics tables) ────────────

_i18n_metric_cache_hit_ratio() {
    case "$CURRENT_LANG" in
        pt-br) echo "Taxa de Acerto do Cache" ;;
        es)    echo "Tasa de Acierto de Caché" ;;
        *)     echo "Cache Hit Ratio" ;;
    esac
}

_i18n_metric_index_usage_ratio() {
    case "$CURRENT_LANG" in
        pt-br) echo "Taxa de Uso de Índices" ;;
        es)    echo "Tasa de Uso de Índices" ;;
        *)     echo "Index Usage Ratio" ;;
    esac
}

_i18n_metric_connections() {
    case "$CURRENT_LANG" in
        pt-br) echo "Conexões" ;;
        es)    echo "Conexiones" ;;
        *)     echo "Connections" ;;
    esac
}

_i18n_metric_idle_connections() {
    case "$CURRENT_LANG" in
        pt-br) echo "Conexões Ociosas" ;;
        es)    echo "Conexiones Inactivas" ;;
        *)     echo "Idle Connections" ;;
    esac
}

_i18n_metric_deadlocks() {
    case "$CURRENT_LANG" in
        pt-br) echo "Deadlocks" ;;
        es)    echo "Deadlocks" ;;
        *)     echo "Deadlocks" ;;
    esac
}

_i18n_metric_temp_bytes_written() {
    case "$CURRENT_LANG" in
        pt-br) echo "Bytes Temporários Escritos" ;;
        es)    echo "Bytes Temporales Escritos" ;;
        *)     echo "Temp Bytes Written" ;;
    esac
}

_i18n_metric_avg_dead_tuple_ratio() {
    case "$CURRENT_LANG" in
        pt-br) echo "Taxa Média de Tuplas Mortas" ;;
        es)    echo "Tasa Promedio de Tuplas Muertas" ;;
        *)     echo "Avg Dead Tuple Ratio" ;;
    esac
}

_i18n_metric_database_size() {
    case "$CURRENT_LANG" in
        pt-br) echo "Tamanho do Banco de Dados" ;;
        es)    echo "Tamaño de la Base de Datos" ;;
        *)     echo "Database Size" ;;
    esac
}

_i18n_metric_memory_usage() {
    case "$CURRENT_LANG" in
        pt-br) echo "Uso de Memória" ;;
        es)    echo "Uso de Memoria" ;;
        *)     echo "Memory Usage" ;;
    esac
}

_i18n_metric_fragmentation_ratio() {
    case "$CURRENT_LANG" in
        pt-br) echo "Taxa de Fragmentação" ;;
        es)    echo "Tasa de Fragmentación" ;;
        *)     echo "Fragmentation Ratio" ;;
    esac
}

_i18n_metric_hit_ratio() {
    case "$CURRENT_LANG" in
        pt-br) echo "Taxa de Acerto" ;;
        es)    echo "Tasa de Acierto" ;;
        *)     echo "Hit Ratio" ;;
    esac
}

_i18n_metric_connected_clients() {
    case "$CURRENT_LANG" in
        pt-br) echo "Clientes Conectados" ;;
        es)    echo "Clientes Conectados" ;;
        *)     echo "Connected Clients" ;;
    esac
}

_i18n_metric_ops_per_sec() {
    case "$CURRENT_LANG" in
        pt-br) echo "Ops/seg" ;;
        es)    echo "Ops/seg" ;;
        *)     echo "Ops/sec" ;;
    esac
}

_i18n_metric_evicted_keys() {
    case "$CURRENT_LANG" in
        pt-br) echo "Chaves Despejadas" ;;
        es)    echo "Claves Desalojadas" ;;
        *)     echo "Evicted Keys" ;;
    esac
}

_i18n_metric_slowlog_entries() {
    case "$CURRENT_LANG" in
        pt-br) echo "Entradas do Slowlog" ;;
        es)    echo "Entradas del Slowlog" ;;
        *)     echo "Slowlog Entries" ;;
    esac
}

_i18n_metric_total_queues() {
    case "$CURRENT_LANG" in
        pt-br) echo "Total de Filas" ;;
        es)    echo "Total de Colas" ;;
        *)     echo "Total Queues" ;;
    esac
}

_i18n_metric_total_connections() {
    case "$CURRENT_LANG" in
        pt-br) echo "Total de Conexões" ;;
        es)    echo "Total de Conexiones" ;;
        *)     echo "Total Connections" ;;
    esac
}

_i18n_metric_total_channels() {
    case "$CURRENT_LANG" in
        pt-br) echo "Total de Canais" ;;
        es)    echo "Total de Canales" ;;
        *)     echo "Total Channels" ;;
    esac
}

_i18n_metric_messages_ready() {
    case "$CURRENT_LANG" in
        pt-br) echo "Mensagens Prontas" ;;
        es)    echo "Mensajes Listos" ;;
        *)     echo "Messages Ready" ;;
    esac
}

_i18n_metric_messages_unacknowledged() {
    case "$CURRENT_LANG" in
        pt-br) echo "Mensagens Não Confirmadas" ;;
        es)    echo "Mensajes Sin Confirmar" ;;
        *)     echo "Messages Unacknowledged" ;;
    esac
}

_i18n_metric_messages_total() {
    case "$CURRENT_LANG" in
        pt-br) echo "Total de Mensagens" ;;
        es)    echo "Total de Mensajes" ;;
        *)     echo "Messages Total" ;;
    esac
}

_i18n_metric_avg_read_latency() {
    case "$CURRENT_LANG" in
        pt-br) echo "Latência Média de Leitura" ;;
        es)    echo "Latencia Promedio de Lectura" ;;
        *)     echo "Avg Read Latency" ;;
    esac
}

_i18n_metric_avg_write_latency() {
    case "$CURRENT_LANG" in
        pt-br) echo "Latência Média de Escrita" ;;
        es)    echo "Latencia Promedio de Escritura" ;;
        *)     echo "Avg Write Latency" ;;
    esac
}

_i18n_metric_resident_memory() {
    case "$CURRENT_LANG" in
        pt-br) echo "Memória Residente" ;;
        es)    echo "Memoria Residente" ;;
        *)     echo "Resident Memory" ;;
    esac
}

_i18n_metric_virtual_memory() {
    case "$CURRENT_LANG" in
        pt-br) echo "Memória Virtual" ;;
        es)    echo "Memoria Virtual" ;;
        *)     echo "Virtual Memory" ;;
    esac
}

_i18n_metric_wiredtiger_cache() {
    case "$CURRENT_LANG" in
        pt-br) echo "Cache WiredTiger" ;;
        es)    echo "Caché WiredTiger" ;;
        *)     echo "WiredTiger Cache" ;;
    esac
}

_i18n_metric_replication_status() {
    case "$CURRENT_LANG" in
        pt-br) echo "Status de Replicação" ;;
        es)    echo "Estado de Replicación" ;;
        *)     echo "Replication Status" ;;
    esac
}

_i18n_metric_used_memory() {
    case "$CURRENT_LANG" in
        pt-br) echo "Memória Utilizada" ;;
        es)    echo "Memoria Utilizada" ;;
        *)     echo "Used Memory" ;;
    esac
}

_i18n_metric_rss() {
    case "$CURRENT_LANG" in
        pt-br) echo "RSS" ;;
        es)    echo "RSS" ;;
        *)     echo "RSS" ;;
    esac
}

_i18n_metric_peak() {
    case "$CURRENT_LANG" in
        pt-br) echo "Pico" ;;
        es)    echo "Pico" ;;
        *)     echo "Peak" ;;
    esac
}

_i18n_metric_lua_engine() {
    case "$CURRENT_LANG" in
        pt-br) echo "Motor Lua" ;;
        es)    echo "Motor Lua" ;;
        *)     echo "Lua Engine" ;;
    esac
}

_i18n_metric_max_memory_limit() {
    case "$CURRENT_LANG" in
        pt-br) echo "Memória Máxima (limite)" ;;
        es)    echo "Memoria Máxima (límite)" ;;
        *)     echo "Max Memory (limit)" ;;
    esac
}

_i18n_metric_eviction_policy() {
    case "$CURRENT_LANG" in
        pt-br) echo "Política de Evicção" ;;
        es)    echo "Política de Desalojo" ;;
        *)     echo "Eviction Policy" ;;
    esac
}

# ── DB Storage Labels ───────────────────────────────────────────────

_i18n_storage_all_databases() {
    case "$CURRENT_LANG" in
        pt-br) echo "Todos os Bancos (Total)" ;;
        es)    echo "Todas las Bases (Total)" ;;
        *)     echo "All Databases (Total)" ;;
    esac
}

_i18n_storage_heap() {
    case "$CURRENT_LANG" in
        pt-br) echo "Heap (Dados das Tabelas)" ;;
        es)    echo "Heap (Datos de Tablas)" ;;
        *)     echo "Heap (Table Data)" ;;
    esac
}

_i18n_storage_indexes() {
    case "$CURRENT_LANG" in
        pt-br) echo "Índices" ;;
        es)    echo "Índices" ;;
        *)     echo "Indexes" ;;
    esac
}

_i18n_storage_data_size() {
    case "$CURRENT_LANG" in
        pt-br) echo "Tamanho dos Dados" ;;
        es)    echo "Tamaño de Datos" ;;
        *)     echo "Data Size" ;;
    esac
}

_i18n_storage_storage_size() {
    case "$CURRENT_LANG" in
        pt-br) echo "Tamanho do Armazenamento" ;;
        es)    echo "Tamaño de Almacenamiento" ;;
        *)     echo "Storage Size" ;;
    esac
}

_i18n_storage_index_size() {
    case "$CURRENT_LANG" in
        pt-br) echo "Tamanho dos Índices" ;;
        es)    echo "Tamaño de Índices" ;;
        *)     echo "Index Size" ;;
    esac
}

_i18n_storage_compression_ratio() {
    case "$CURRENT_LANG" in
        pt-br) echo "Taxa de Compressão" ;;
        es)    echo "Tasa de Compresión" ;;
        *)     echo "Compression Ratio" ;;
    esac
}

_i18n_metric_repl_set_status_replica() {
    case "$CURRENT_LANG" in
        pt-br) echo "conjunto de réplicas" ;;
        es)    echo "conjunto de réplicas" ;;
        *)     echo "replica set" ;;
    esac
}

_i18n_metric_repl_set_status_none() {
    case "$CURRENT_LANG" in
        pt-br) echo "nenhum" ;;
        es)    echo "ninguno" ;;
        *)     echo "none" ;;
    esac
}

_i18n_label_yes() {
    case "$CURRENT_LANG" in
        pt-br) echo "Sim" ;;
        es)    echo "Sí" ;;
        *)     echo "Yes" ;;
    esac
}

_i18n_label_no() {
    case "$CURRENT_LANG" in
        pt-br) echo "Não" ;;
        es)    echo "No" ;;
        *)     echo "No" ;;
    esac
}

_i18n_label_version() {
    case "$CURRENT_LANG" in
        pt-br) echo "Versão" ;;
        es)    echo "Versión" ;;
        *)     echo "Version" ;;
    esac
}

_i18n_label_host() {
    case "$CURRENT_LANG" in
        pt-br) echo "Host" ;;
        es)    echo "Host" ;;
        *)     echo "Host" ;;
    esac
}

_i18n_label_database() {
    case "$CURRENT_LANG" in
        pt-br) echo "Banco de Dados" ;;
        es)    echo "Base de Datos" ;;
        *)     echo "Database" ;;
    esac
}

_i18n_label_engine() {
    case "$CURRENT_LANG" in
        pt-br) echo "Motor" ;;
        es)    echo "Motor" ;;
        *)     echo "Engine" ;;
    esac
}

_i18n_label_role() {
    case "$CURRENT_LANG" in
        pt-br) echo "Função" ;;
        es)    echo "Rol" ;;
        *)     echo "Role" ;;
    esac
}

_i18n_label_uptime() {
    case "$CURRENT_LANG" in
        pt-br) echo "Tempo Ativo" ;;
        es)    echo "Tiempo Activo" ;;
        *)     echo "Uptime" ;;
    esac
}

_i18n_label_days() {
    case "$CURRENT_LANG" in
        pt-br) echo "dias" ;;
        es)    echo "días" ;;
        *)     echo "days" ;;
    esac
}

_i18n_label_cluster_name() {
    case "$CURRENT_LANG" in
        pt-br) echo "Nome do Cluster" ;;
        es)    echo "Nombre del Clúster" ;;
        *)     echo "Cluster Name" ;;
    esac
}

_i18n_label_used() {
    case "$CURRENT_LANG" in
        pt-br) echo "usado" ;;
        es)    echo "usado" ;;
        *)     echo "used" ;;
    esac
}

# ── Context / Guide Strings ──────────────────────────────────────────

_i18n_scoring_methodology_text() {
    case "$CURRENT_LANG" in
        pt-br) echo "**Metodologia de Pontuação:** Cada categoria é pontuada de 0 a 100 com base em múltiplos indicadores de saúde. A pontuação geral é uma média ponderada que reflete as prioridades do cluster." ;;
        es)    echo "**Metodología de Puntuación:** Cada categoría se puntúa de 0 a 100 según múltiples indicadores de salud. La puntuación general es un promedio ponderado que refleja las prioridades del clúster." ;;
        *)     echo "**Scoring Methodology:** Each category is scored 0-100 based on multiple health indicators. The overall score is a weighted average reflecting cluster priorities." ;;
    esac
}

_i18n_pro_tip_report() {
    case "$CURRENT_LANG" in
        pt-br) echo "**Dica Profissional:** Este relatório fornece um panorama completo da utilização de recursos, distribuição de cargas de trabalho e métricas gerais de saúde do seu cluster Kubernetes." ;;
        es)    echo "**Consejo Profesional:** Este informe proporciona una visión completa de la utilización de recursos, distribución de cargas de trabajo y métricas generales de salud de su clúster Kubernetes." ;;
        *)     echo "**Pro Tip:** This report provides a comprehensive snapshot of your Kubernetes cluster's resource utilization, workload distribution, and overall health metrics." ;;
    esac
}

_i18n_metrics_server_note() {
    case "$CURRENT_LANG" in
        pt-br) echo "**Crítico:** Os dados de recursos em tempo real requerem o \`metrics-server\` (um pequeno programa que coleta o uso de CPU e memória de cada pod). Sem ele, não é possível ver quanto cada aplicação está realmente consumindo." ;;
        es)    echo "**Crítico:** Los datos de recursos en tiempo real requieren \`metrics-server\` (un pequeño programa que recopila el uso de CPU y memoria de cada pod). Sin él, no es posible ver cuánto está consumiendo realmente cada aplicación." ;;
        *)     echo "**Critical:** Real-time resource data requires \`metrics-server\` (a small program that collects CPU and memory usage from every pod). Without it, you cannot see how much each application is actually consuming." ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════
# MULTI-LINE BLOCKS — Score Interpretation
# ═══════════════════════════════════════════════════════════════════════

_i18n_block_score_interpretation() {
    case "$CURRENT_LANG" in
        pt-br) cat <<'PTBR'
- **90-100 (Excelente):** Melhores práticas seguidas, nenhum problema detectado
- **75-89 (Bom):** Pequenas melhorias possíveis
- **50-74 (Regular):** Ação recomendada
- **30-49 (Ruim):** Ação necessária
- **0-29 (Crítico):** Ação imediata necessária
PTBR
            ;;
        es) cat <<'ES'
- **90-100 (Excelente):** Mejores prácticas seguidas, sin problemas detectados
- **75-89 (Bueno):** Mejoras menores posibles
- **50-74 (Regular):** Acción recomendada
- **30-49 (Deficiente):** Acción requerida
- **0-29 (Crítico):** Acción inmediata requerida
ES
            ;;
        *) cat <<'EN'
- **90-100 (Excellent):** Best practices followed, no issues detected
- **75-89 (Good):** Minor improvements possible
- **50-74 (Fair):** Action recommended
- **30-49 (Poor):** Action required
- **0-29 (Critical):** Immediate action required
EN
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════
# MULTI-LINE BLOCKS — "What Good Looks Like" (WGLL)
# ═══════════════════════════════════════════════════════════════════════

_i18n_block_wgll_nodes() {
    case "$CURRENT_LANG" in
        pt-br) cat <<'PTBR'
> **Como Deve Ser:**
> - Todos os nós devem estar no estado `Ready`. Um nó `NotReady` significa que o Kubernetes perdeu contato com ele — suas cargas de trabalho não podem ser executadas e serão reagendadas para outros nós. Investigue imediatamente.
> - Uso de CPU abaixo de 70% por nó é saudável. Uso sustentado acima de 80% significa que o nó está sobrecarregado — adicione mais nós (escalar horizontalmente) ou use nós maiores (escalar verticalmente). Diferente da memória, a CPU pode ser limitada (desacelerada) em vez de encerrada.
> - Uso de memória abaixo de 75% por nó é ideal. Diferente da CPU, a memória não pode ser comprimida — quando acaba, o Kubernetes encerra containers à força (chamado de Out-of-Memory ou OOM kill) sem desligamento gracioso. Isso pode causar perda de dados.
> - Os nós devem estar distribuídos em múltiplas zonas de disponibilidade (localizações separadas de data center). Se uma zona tiver uma interrupção, as outras mantêm o cluster funcionando.
PTBR
            ;;
        es) cat <<'ES'
> **Cómo Debería Ser:**
> - Todos los nodos deben estar en estado `Ready`. Un nodo `NotReady` significa que Kubernetes perdió contacto con él — sus cargas de trabajo no pueden ejecutarse y serán reprogramadas en otros nodos. Investigue inmediatamente.
> - El uso de CPU por debajo del 70% por nodo es saludable. Un uso sostenido por encima del 80% significa que el nodo está sobrecargado — agregue más nodos (escalar horizontalmente) o use nodos más grandes (escalar verticalmente). A diferencia de la memoria, la CPU puede ser limitada (ralentizada) en lugar de terminada.
> - El uso de memoria por debajo del 75% por nodo es ideal. A diferencia de la CPU, la memoria no se puede comprimir — cuando se agota, Kubernetes termina contenedores a la fuerza (llamado Out-of-Memory u OOM kill) sin apagado gracioso. Esto puede causar pérdida de datos.
> - Los nodos deben estar distribuidos en múltiples zonas de disponibilidad (ubicaciones separadas de centros de datos). Si una zona tiene una interrupción, las demás mantienen el clúster en funcionamiento.
ES
            ;;
        *) cat <<'EN'
> **What Good Looks Like:**
> - All nodes should be in `Ready` state. A `NotReady` node means Kubernetes has lost contact with it — its workloads cannot run and will be rescheduled to other nodes. Investigate immediately.
> - CPU usage below 70% per node is healthy. Sustained usage above 80% means the node is struggling — either add more nodes (scale out) or use bigger nodes (scale up). Unlike memory, CPU can be throttled (slowed down) rather than killed.
> - Memory usage below 75% per node is ideal. Unlike CPU, memory cannot be compressed — when it runs out, Kubernetes forcibly terminates containers (called Out-of-Memory or OOM kills) with no graceful shutdown. This can cause data loss.
> - Nodes should be spread across multiple availability zones (separate data-center locations). If one zone has an outage, the others keep the cluster running.
EN
            ;;
    esac
}

_i18n_block_wgll_node_capacity() {
    case "$CURRENT_LANG" in
        pt-br) cat <<'PTBR'
> **Como Deve Ser:**
> - Uma pequena diferença entre Capacidade e Alocável (5-15%) é normal. 'Capacidade' é o total de recursos na máquina; 'Alocável' é o que o Kubernetes pode realmente fornecer às suas aplicações. A diferença é reservada para o sistema operacional e o próprio Kubernetes.
> - Se Alocável é igual à Capacidade, nada está reservado para o sistema. Isso é aceitável para desenvolvimento, mas em produção os processos do sistema podem ficar sem recursos e travar — derrubando o nó inteiro.
> - Especificações uniformes de nós (todos os nós do mesmo tamanho) facilitam o planejamento de capacidade e a previsão de comportamento. Tamanhos mistos podem levar alguns nós a ficarem sobrecarregados enquanto outros ficam ociosos.
PTBR
            ;;
        es) cat <<'ES'
> **Cómo Debería Ser:**
> - Una pequeña diferencia entre Capacidad y Asignable (5-15%) es normal. 'Capacidad' es el total de recursos en la máquina; 'Asignable' es lo que Kubernetes puede realmente asignar a sus aplicaciones. La diferencia se reserva para el sistema operativo y Kubernetes mismo.
> - Si Asignable es igual a Capacidad, no hay nada reservado para el sistema. Esto es aceptable para desarrollo, pero en producción los procesos del sistema podrían quedarse sin recursos y fallar — derribando el nodo entero.
> - Especificaciones uniformes de nodos (todos los nodos del mismo tamaño) facilitan la planificación de capacidad y la predicción de comportamiento. Tamaños mixtos pueden hacer que algunos nodos se sobrecarguen mientras otros permanecen inactivos.
ES
            ;;
        *) cat <<'EN'
> **What Good Looks Like:**
> - A small gap between Capacity and Allocatable (5-15%) is normal. 'Capacity' is the total resources on the machine; 'Allocatable' is what Kubernetes can actually give to your applications. The difference is reserved for the operating system and Kubernetes itself.
> - If Allocatable equals Capacity, nothing is reserved for the system. This is fine for development, but in production the system processes could run out of resources and crash — taking down the entire node.
> - Uniform node specs (all nodes the same size) make it easier to plan capacity and predict behavior. Mixed sizes can lead to some nodes being overloaded while others sit idle.
EN
            ;;
    esac
}

_i18n_block_wgll_pods() {
    case "$CURRENT_LANG" in
        pt-br) cat <<'PTBR'
> **Como Deve Ser:**
> - O uso de CPU do pod deve ficar bem abaixo do seu limite. Quando um pod atinge seu limite de CPU, o Kubernetes o desacelera (chamado de 'throttling') — sua aplicação ainda funciona, mas responde muito mais lentamente.
> - O uso de memória do pod deve ficar abaixo de 80% do seu limite. Quando um pod excede seu limite de memória, o Kubernetes o encerra imediatamente (chamado de 'OOM kill' — Out of Memory) e o reinicia. Isso pode causar breves indisponibilidades e perda de trabalho em andamento.
> - Pods mostrando `0m` ou `1m` de CPU estão essencialmente ociosos (sem fazer nada). Isso é normal para serviços de baixo tráfego, mas pode significar que o serviço não está recebendo nenhum tráfego.
> - Se um pod está usando muito mais recursos que os outros, ele pode ter um vazamento de memória (consumindo cada vez mais memória ao longo do tempo), consultas ineficientes ao banco de dados ou um bug no código causando processamento infinito.
PTBR
            ;;
        es) cat <<'ES'
> **Cómo Debería Ser:**
> - El uso de CPU del pod debe mantenerse bien por debajo de su límite. Cuando un pod alcanza su límite de CPU, Kubernetes lo ralentiza (llamado 'throttling') — su aplicación sigue funcionando pero responde mucho más lento.
> - El uso de memoria del pod debe mantenerse por debajo del 80% de su límite. Cuando un pod excede su límite de memoria, Kubernetes lo termina inmediatamente (llamado 'OOM kill' — Out of Memory) y lo reinicia. Esto puede causar breves interrupciones y pérdida de trabajo en curso.
> - Pods que muestran `0m` o `1m` de CPU están esencialmente inactivos (sin hacer nada). Esto es normal para servicios de bajo tráfico, pero podría significar que el servicio no está recibiendo tráfico en absoluto.
> - Si un pod está usando muchos más recursos que los demás, puede tener una fuga de memoria (consumiendo cada vez más memoria con el tiempo), consultas ineficientes a la base de datos o un bug en el código que causa procesamiento infinito.
ES
            ;;
        *) cat <<'EN'
> **What Good Looks Like:**
> - Pod CPU usage should stay well below its limit. When a pod hits its CPU limit, Kubernetes slows it down (called 'throttling') — your application still runs but responds much slower.
> - Pod memory usage should stay below 80% of its limit. When a pod exceeds its memory limit, Kubernetes kills it immediately (called an 'OOM kill' — Out of Memory) and restarts it. This can cause brief downtime and lost in-progress work.
> - Pods showing `0m` or `1m` CPU are essentially idle (doing nothing). This is normal for low-traffic services but might mean the service is not receiving any traffic at all.
> - If one pod is using far more resources than the others, it may have a memory leak (slowly consuming more and more memory over time), inefficient database queries, or a code bug causing it to spin endlessly.
EN
            ;;
    esac
}

_i18n_block_wgll_deployments() {
    case "$CURRENT_LANG" in
        pt-br) cat <<'PTBR'
> **Como Deve Ser:**
> - Todo deployment deve ter Ready igual a Desired. Se não coincidem, algumas cópias da sua aplicação falharam ao iniciar — verifique os logs em busca de mensagens de erro e os eventos em busca de pistas.
> - Executar apenas 1 cópia (réplica) de um serviço significa que, se ele falhar, seus usuários terão indisponibilidade até que ele reinicie. Para qualquer coisa importante, execute pelo menos 2 cópias para que uma possa assumir se a outra falhar.
> - Se um deployment está travado na atualização (Ready nunca alcança Desired), as causas mais comuns são: a imagem do container da nova versão não existe, a aplicação falha ao iniciar ou não há recursos suficientes no cluster.
> - Para atualizações sem indisponibilidade, defina `maxUnavailable: 0` na estratégia do deployment. Isso garante que o Kubernetes inicie a nova versão antes de parar a antiga.
PTBR
            ;;
        es) cat <<'ES'
> **Cómo Debería Ser:**
> - Cada deployment debe tener Ready igual a Desired. Si no coinciden, algunas copias de su aplicación fallaron al iniciar — revise los logs en busca de mensajes de error y los eventos en busca de pistas.
> - Ejecutar solo 1 copia (réplica) de un servicio significa que, si falla, sus usuarios experimentarán una interrupción hasta que se reinicie. Para cualquier cosa importante, ejecute al menos 2 copias para que una pueda tomar el relevo si la otra falla.
> - Si un deployment está atascado actualizándose (Ready nunca alcanza a Desired), las causas más comunes son: la imagen del contenedor de la nueva versión no existe, la aplicación falla al iniciar o no hay suficientes recursos en el clúster.
> - Para actualizaciones sin interrupciones, establezca `maxUnavailable: 0` en la estrategia del deployment. Esto asegura que Kubernetes inicie la nueva versión antes de detener la anterior.
ES
            ;;
        *) cat <<'EN'
> **What Good Looks Like:**
> - Every deployment should have Ready equal to Desired. If they don't match, some copies of your application failed to start — check logs for error messages and events for clues.
> - Running only 1 copy (replica) of a service means if it crashes, your users experience downtime until it restarts. For anything important, run at least 2 copies so one can take over if the other fails.
> - If a deployment is stuck updating (Ready never catches up to Desired), the most common causes are: the new version's container image doesn't exist, the app crashes on startup, or there aren't enough resources on the cluster.
> - For zero-downtime updates, set `maxUnavailable: 0` in your deployment strategy. This ensures Kubernetes starts the new version before stopping the old one.
EN
            ;;
    esac
}

_i18n_block_wgll_resources() {
    case "$CURRENT_LANG" in
        pt-br) cat <<'PTBR'
> **Como Deve Ser:**
> - **Requests** devem corresponder ao que sua aplicação normalmente usa. Solicitar demais desperdiça dinheiro (recursos ficam reservados mas sem uso). Solicitar de menos significa que o Kubernetes pode colocar muitas aplicações em uma máquina, causando lentidão.
> - **Limits** devem ser 1,5-2x o valor do request. Isso dá à sua aplicação espaço para lidar com picos de tráfego. Muito apertado = lentidão constante; muito frouxo = uma aplicação com problema pode prejudicar todas as outras na mesma máquina.
> - Requests totais de CPU entre 50-80% do que o cluster pode fornecer é o ponto ideal. Abaixo de 30% significa que você está pagando significativamente a mais por capacidade não utilizada. Acima de 85% significa que não há espaço para picos de tráfego ou falhas de máquinas.
> - Requests totais de memória entre 50-75% é ideal. Diferente da CPU (que apenas fica mais lenta quando restrita), a memória não pode ser comprimida — quando acaba, as aplicações são encerradas à força.
PTBR
            ;;
        es) cat <<'ES'
> **Cómo Debería Ser:**
> - **Requests** deben corresponder a lo que su aplicación normalmente usa. Solicitar demasiado desperdicia dinero (los recursos quedan reservados pero sin uso). Solicitar muy poco significa que Kubernetes puede colocar demasiadas aplicaciones en una máquina, causando lentitud.
> - **Limits** deben ser 1,5-2x el valor del request. Esto le da a su aplicación margen para manejar picos de tráfico. Muy ajustado = lentitud constante; muy holgado = una aplicación con problemas puede afectar a todas las demás en la misma máquina.
> - Requests totales de CPU entre 50-80% de lo que el clúster puede proporcionar es el punto ideal. Por debajo del 30% significa que está pagando significativamente de más por capacidad no utilizada. Por encima del 85% significa que no hay margen para picos de tráfico o fallos de máquinas.
> - Requests totales de memoria entre 50-75% es ideal. A diferencia de la CPU (que solo se ralentiza cuando está restringida), la memoria no se puede comprimir — cuando se agota, las aplicaciones se terminan a la fuerza.
ES
            ;;
        *) cat <<'EN'
> **What Good Looks Like:**
> - **Requests** should match what your app normally uses. Requesting too much wastes money (resources sit reserved but unused). Requesting too little means Kubernetes may place too many apps on one machine, causing slowdowns.
> - **Limits** should be 1.5-2x the request value. This gives your app room to handle traffic spikes. Too tight = constant slowdowns; too loose = one misbehaving app can starve everything else on the same machine.
> - Total CPU requests between 50-80% of what the cluster can provide is the sweet spot. Below 30% means you are significantly overpaying for unused capacity. Above 85% means there is no room for traffic spikes or machine failures.
> - Total memory requests between 50-75% is ideal. Unlike CPU (which just gets slower when constrained), memory cannot be compressed — when it runs out, applications get forcibly killed.
EN
            ;;
    esac
}

_i18n_block_wgll_security() {
    case "$CURRENT_LANG" in
        pt-br) cat <<'PTBR'
> **Como Deve Ser:**
> - `cluster-admin` é o superusuário do Kubernetes — pode fazer tudo. Mantenha essas vinculações em 1-2 apenas para uso de emergência. Cada cluster-admin adicional é uma potencial porta de entrada para um atacante assumir o controle de todo o cluster.
> - Prefira Roles com escopo de namespace em vez de ClusterRoles. Um Role de namespace limita os danos: se uma conta de serviço for comprometida, o atacante só pode afetar um namespace, não o cluster inteiro. Pense nisso como dar a alguém uma chave para um cômodo versus uma chave mestra para o prédio inteiro.
> - Defina `automountServiceAccountToken: false` em pods que não precisam se comunicar com a API do Kubernetes (a maioria das aplicações não precisa). Esse token é como uma senha — se um hacker invadir seu pod, ele pode usá-lo para controlar o cluster.
> - Cada aplicação deve usar sua própria ServiceAccount dedicada, não a `default`. A ServiceAccount default pode ter mais permissões do que você imagina, e compartilhá-la entre aplicações significa que uma violação em uma aplicação dá acesso a todas.
PTBR
            ;;
        es) cat <<'ES'
> **Cómo Debería Ser:**
> - `cluster-admin` es el superusuario de Kubernetes — puede hacer todo. Mantenga estas vinculaciones en 1-2 solo para uso de emergencia. Cada cluster-admin adicional es una puerta potencial para que un atacante tome el control de todo el clúster.
> - Prefiera Roles con alcance de namespace sobre ClusterRoles. Un Role de namespace limita el daño: si una cuenta de servicio se ve comprometida, el atacante solo puede afectar un namespace, no todo el clúster. Piénselo como dar a alguien una llave de una habitación versus una llave maestra de todo el edificio.
> - Establezca `automountServiceAccountToken: false` en pods que no necesitan comunicarse con la API de Kubernetes (la mayoría de las aplicaciones no lo necesitan). Este token es como una contraseña — si un hacker compromete su pod, puede usarlo para controlar el clúster.
> - Cada aplicación debe usar su propia ServiceAccount dedicada, no la `default`. La ServiceAccount default puede tener más permisos de los que usted cree, y compartirla entre aplicaciones significa que una brecha en una aplicación da acceso a todas.
ES
            ;;
        *) cat <<'EN'
> **What Good Looks Like:**
> - `cluster-admin` is the superuser of Kubernetes — it can do everything. Keep these bindings to 1-2 for emergency use only. Each additional cluster-admin is a potential doorway for an attacker to take over the entire cluster.
> - Prefer namespace-scoped Roles over ClusterRoles. A namespace Role limits damage: if a service account is compromised, the attacker can only affect one namespace, not the whole cluster. Think of it like giving someone a key to one room vs. a master key to the entire building.
> - Set `automountServiceAccountToken: false` on pods that don't need to talk to the Kubernetes API (most apps don't). This token is like a password — if a hacker breaks into your pod, they can use it to control the cluster.
> - Every application should use its own dedicated ServiceAccount, not the `default` one. The default ServiceAccount might have more permissions than you realize, and sharing it between apps means a breach in one app gives access to all.
EN
            ;;
    esac
}

_i18n_block_wgll_storage() {
    case "$CURRENT_LANG" in
        pt-br) cat <<'PTBR'
> **Como Deve Ser:**
> - Todos os PVCs devem mostrar o status `Bound` (significando que um disco foi atribuído). Um PVC `Pending` significa que o Kubernetes não conseguiu encontrar ou criar um disco correspondente — verifique se o StorageClass existe, se o tamanho solicitado está disponível e se o modo de acesso é suportado.
> - Use o modo de vinculação `WaitForFirstConsumer` para que o disco seja criado na mesma zona de data center da aplicação que precisa dele. Sem isso, você pode ter um disco na zona A e um pod na zona B — e eles não conseguem se conectar.
> - Defina um StorageClass como padrão para que as equipes não precisem codificar `storageClassName` em cada carga de trabalho. Isso reduz inconsistências entre namespaces.
> - Habilite a expansão de volume nos StorageClasses principais da aplicação para que um disco cheio possa ser corrigido sem recriar volumes e mover dados.
PTBR
            ;;
        es) cat <<'ES'
> **Cómo Debería Ser:**
> - Todos los PVCs deben mostrar estado `Bound` (lo que significa que se ha asignado un disco). Un PVC `Pending` significa que Kubernetes no pudo encontrar o crear un disco correspondiente — verifique que el StorageClass exista, que el tamaño solicitado esté disponible y que el modo de acceso sea compatible.
> - Use el modo de vinculación `WaitForFirstConsumer` para que el disco se cree en la misma zona del centro de datos que la aplicación que lo necesita. Sin esto, podría obtener un disco en la zona A y un pod en la zona B — y no pueden conectarse.
> - Establezca un StorageClass como predeterminado para que los equipos no necesiten especificar `storageClassName` en cada carga de trabajo. Esto reduce inconsistencias entre namespaces.
> - Habilite la expansión de volumen en los StorageClasses principales de la aplicación para que un disco lleno pueda corregirse sin recrear volúmenes y mover datos.
ES
            ;;
        *) cat <<'EN'
> **What Good Looks Like:**
> - All PVCs should show `Bound` status (meaning a disk has been assigned). A `Pending` PVC means Kubernetes could not find or create a matching disk — check that the StorageClass exists, the requested size is available, and the access mode is supported.
> - Use `WaitForFirstConsumer` binding mode so the disk is created in the same data center zone as the application that needs it. Without this, you might get a disk in zone A and a pod in zone B — and they cannot connect.
> - Set one StorageClass as the default so teams do not need to hardcode `storageClassName` in every workload. This reduces drift across namespaces.
> - Enable volume expansion on the main application StorageClasses so a full disk can be fixed without recreating volumes and moving data.
EN
            ;;
    esac
}

_i18n_block_wgll_events() {
    case "$CURRENT_LANG" in
        pt-br) cat <<'PTBR'
> **Como Deve Ser:**
> - Um cluster saudável tem mais de 90% de eventos Normal. Eventos de Warning devem ficar abaixo de 10%. Se você vir warnings aparecendo repetidamente, investigue — um warning recorrente é um sintoma de um problema subjacente que não se resolverá sozinho.
> - Razões críticas de warning como `CrashLoopBackOff`, falhas de pull de imagem, falhas de montagem ou falhas de agendamento devem ficar próximas de zero. Elas geralmente correspondem diretamente a interrupções visíveis para o usuário.
> - A tabela de Principais Razões de Eventos acima é a fonte de evidência para remediação. Priorize a razão de warning com maior contagem primeiro, em vez de aplicar correções genéricas.
> - Sempre corrija a causa raiz dos warnings em vez de ignorá-los. Suprimir warnings sem corrigir o problema subjacente leva a problemas maiores depois.
PTBR
            ;;
        es) cat <<'ES'
> **Cómo Debería Ser:**
> - Un clúster saludable tiene más del 90% de eventos Normal. Los eventos Warning deben estar por debajo del 10%. Si ve warnings apareciendo repetidamente, investigue — un warning recurrente es un síntoma de un problema subyacente que no se resolverá solo.
> - Razones críticas de warning como `CrashLoopBackOff`, fallos de descarga de imagen, fallos de montaje o fallos de programación deben mantenerse cerca de cero. Generalmente corresponden directamente a interrupciones visibles para el usuario.
> - La tabla de Principales Razones de Eventos arriba es la fuente de evidencia para remediación. Priorice la razón de warning con mayor conteo primero, en lugar de aplicar correcciones genéricas.
> - Siempre corrija la causa raíz de los warnings en lugar de ignorarlos. Suprimir warnings sin corregir el problema subyacente lleva a problemas mayores después.
ES
            ;;
        *) cat <<'EN'
> **What Good Looks Like:**
> - A healthy cluster has over 90% Normal events. Warning events should be under 10%. If you see warnings appearing repeatedly, investigate — a recurring warning is a symptom of an underlying problem that won't fix itself.
> - Critical warning reasons such as `CrashLoopBackOff`, image pull failures, mount failures, or failed scheduling should stay close to zero. They usually map directly to user-visible outages.
> - The Top Event Reasons table above is the evidence source for remediation. Prioritize the highest-count warning reason first instead of applying generic fixes.
> - Always fix the root cause of warnings rather than ignoring them. Suppressing warnings without fixing the underlying issue leads to bigger problems later.
EN
            ;;
    esac
}

_i18n_block_wgll_networking() {
    case "$CURRENT_LANG" in
        pt-br) cat <<'PTBR'
> **Como Deve Ser:**
> - A maioria dos services deve ser `ClusterIP` (apenas interno). Só exponha services externamente quando eles genuinamente precisarem ser acessados de fora do cluster. Menos services expostos = menor superfície de ataque.
> - Services do tipo LoadBalancer devem ter um IP externo atribuído. Se um mostrar `Pending`, o provedor de nuvem não conseguiu criar o load balancer — causas comuns: problemas de cobrança, limites de cota ou permissões ausentes.
> - Evite `NodePort` em produção. Ele abre uma porta em todas as máquinas e ignora seu ingress controller (o gateway central que cuida de segurança, limitação de taxa e roteamento).
> - Cada service deve ter pelo menos um endpoint saudável (um pod em execução que corresponda). Um service sem endpoints significa que o tráfego não vai a lugar nenhum — geralmente causado por uma incompatibilidade de labels entre o Service e seus Pods.
PTBR
            ;;
        es) cat <<'ES'
> **Cómo Debería Ser:**
> - La mayoría de los services deben ser `ClusterIP` (solo interno). Solo exponga services externamente cuando genuinamente necesiten ser accedidos desde fuera del clúster. Menos services expuestos = menor superficie de ataque.
> - Los services de tipo LoadBalancer deben tener una IP externa asignada. Si uno muestra `Pending`, el proveedor de nube no pudo crear el balanceador de carga — causas comunes: problemas de facturación, límites de cuota o permisos faltantes.
> - Evite `NodePort` en producción. Abre un puerto en todas las máquinas y omite su ingress controller (la puerta de enlace central que maneja seguridad, limitación de tasa y enrutamiento).
> - Cada service debe tener al menos un endpoint saludable (un pod en ejecución que coincida). Un service sin endpoints significa que el tráfico no va a ningún lado — generalmente causado por una incompatibilidad de labels entre el Service y sus Pods.
ES
            ;;
        *) cat <<'EN'
> **What Good Looks Like:**
> - Most services should be `ClusterIP` (internal only). Only expose services externally when they genuinely need to be reached from outside the cluster. Fewer exposed services = smaller attack surface.
> - LoadBalancer services should have an assigned external IP. If one shows `Pending`, the cloud provider could not create the load balancer — common causes: billing issues, quota limits, or missing permissions.
> - Avoid `NodePort` in production. It opens a port on every machine and bypasses your ingress controller (the central gateway that handles security, rate limiting, and routing).
> - Every service should have at least one healthy endpoint (a running pod that matches). A service with no endpoints means traffic goes nowhere — usually caused by a label mismatch between the Service and its Pods.
EN
            ;;
    esac
}

_i18n_block_wgll_network_policies() {
    case "$CURRENT_LANG" in
        pt-br) cat <<'PTBR'
> **Como Deve Ser:**
> - Clusters de produção devem ter NetworkPolicies. Sem elas, se um atacante comprometer uma aplicação, ele pode acessar livremente seus bancos de dados, filas de mensagens e todos os outros serviços no cluster.
> - Comece com uma regra de 'negar todo tráfego de entrada' para cada namespace, depois crie regras específicas para permitir apenas as conexões que são realmente necessárias. Isso é chamado de 'rede zero-trust' — não confie em nada por padrão.
> - Bancos de dados e filas de mensagens devem aceitar conexões apenas das aplicações específicas que precisam deles. Por exemplo, apenas seu serviço de API deve poder se conectar ao seu banco de dados — não seu frontend, não seu coletor de logs, nada mais.
PTBR
            ;;
        es) cat <<'ES'
> **Cómo Debería Ser:**
> - Los clústeres de producción deben tener NetworkPolicies. Sin ellas, si un atacante compromete una aplicación, puede acceder libremente a sus bases de datos, colas de mensajes y todos los demás servicios del clúster.
> - Comience con una regla de 'denegar todo el tráfico entrante' para cada namespace, luego cree reglas específicas para permitir solo las conexiones que realmente se necesitan. Esto se llama 'red de confianza cero' — no confíe en nada por defecto.
> - Las bases de datos y colas de mensajes solo deben aceptar conexiones de las aplicaciones específicas que las necesitan. Por ejemplo, solo su servicio de API debe poder conectarse a su base de datos — no su frontend, no su recolector de logs, nada más.
ES
            ;;
        *) cat <<'EN'
> **What Good Looks Like:**
> - Production clusters should have NetworkPolicies. Without them, if an attacker compromises one application, they can freely reach your databases, message queues, and every other service in the cluster.
> - Start with a 'deny all incoming traffic' rule for each namespace, then create specific rules to allow only the connections that are actually needed. This is called 'zero-trust networking' — trust nothing by default.
> - Databases and message queues should only accept connections from the specific applications that need them. For example, only your API service should be able to connect to your database — not your frontend, not your log collector, not anything else.
EN
            ;;
    esac
}

_i18n_block_wgll_config() {
    case "$CURRENT_LANG" in
        pt-br) cat <<'PTBR'
> **Como Deve Ser:**
> - Todo namespace de produção deve ter ResourceQuotas. Sem elas, uma equipe pode acidentalmente (ou intencionalmente) usar toda a CPU e memória do cluster, prejudicando as aplicações de todos os outros.
> - LimitRanges garantem que mesmo pods implantados sem configurações explícitas de recursos recebam valores padrão sensatos. Sem LimitRanges, um container sem limite de memória pode consumir toda a memória do seu nó e derrubar tudo que está rodando ali.
> - Um LimitRange típico para produção: request padrão de CPU 100m (um décimo de um core), limit padrão de CPU 500m, request padrão de memória 128Mi (128 megabytes), limit padrão de memória 512Mi. Ajuste esses valores com base nas necessidades reais das suas cargas de trabalho.
> - Sem ResourceQuotas, um único deployment mal configurado (por exemplo, alguém acidentalmente define 1000 réplicas) pode consumir todos os recursos disponíveis no cluster, causando uma interrupção em cascata em todos os serviços.
PTBR
            ;;
        es) cat <<'ES'
> **Cómo Debería Ser:**
> - Cada namespace de producción debe tener ResourceQuotas. Sin ellas, un equipo podría accidentalmente (o intencionalmente) usar toda la CPU y memoria del clúster, afectando las aplicaciones de todos los demás.
> - LimitRanges aseguran que incluso pods desplegados sin configuraciones explícitas de recursos reciban valores predeterminados razonables. Sin LimitRanges, un contenedor sin límite de memoria podría consumir toda la memoria de su nodo y derribar todo lo demás que esté ejecutándose allí.
> - Un LimitRange típico para producción: request predeterminado de CPU 100m (una décima de un core), limit predeterminado de CPU 500m, request predeterminado de memoria 128Mi (128 megabytes), limit predeterminado de memoria 512Mi. Ajuste estos valores según las necesidades reales de sus cargas de trabajo.
> - Sin ResourceQuotas, un solo deployment mal configurado (por ejemplo, alguien accidentalmente establece 1000 réplicas) podría consumir todos los recursos disponibles del clúster, causando una interrupción en cascada en todos los servicios.
ES
            ;;
        *) cat <<'EN'
> **What Good Looks Like:**
> - Every production namespace should have ResourceQuotas. Without them, one team could accidentally (or intentionally) use all the cluster's CPU and memory, starving everyone else's applications.
> - LimitRanges ensure that even pods deployed without explicit resource settings get sensible defaults. Without LimitRanges, a container with no memory limit could consume all memory on its node and crash everything else running there.
> - A typical LimitRange for production: default CPU request 100m (one-tenth of a core), default CPU limit 500m, default memory request 128Mi (128 megabytes), default memory limit 512Mi. Adjust these based on your actual workload needs.
> - Without ResourceQuotas, a single misconfigured deployment (e.g., someone accidentally sets 1000 replicas) could consume every available resource in the cluster, causing a cascading outage across all services.
EN
            ;;
    esac
}

_i18n_block_wgll_configmaps() {
    case "$CURRENT_LANG" in
        pt-br) cat <<'PTBR'
> **Como Deve Ser:**
> - ConfigMaps nunca devem conter senhas, chaves de API ou tokens. Se você encontrar algum, mova-os para Secrets imediatamente — ConfigMaps são legíveis por qualquer pessoa com acesso ao cluster e não foram projetados para proteger dados sensíveis.
> - ConfigMaps muito grandes (mais de 100 entradas) sugerem proliferação de configurações. Divida-os em ConfigMaps menores e focados — um por serviço ou área funcional — para que sejam mais fáceis de gerenciar e auditar.
> - Cada ConfigMap deve ser usado por pelo menos uma aplicação em execução. ConfigMaps órfãos (não referenciados por nenhum pod) adicionam desordem e podem conter configurações desatualizadas ou enganosas.
PTBR
            ;;
        es) cat <<'ES'
> **Cómo Debería Ser:**
> - Los ConfigMaps nunca deben contener contraseñas, claves de API o tokens. Si encuentra alguno, muévalos a Secrets inmediatamente — los ConfigMaps son legibles por cualquier persona con acceso al clúster y no están diseñados para proteger datos sensibles.
> - ConfigMaps muy grandes (más de 100 entradas) sugieren proliferación de configuraciones. Divídalos en ConfigMaps más pequeños y enfocados — uno por servicio o área funcional — para que sean más fáciles de administrar y auditar.
> - Cada ConfigMap debe ser usado por al menos una aplicación en ejecución. ConfigMaps huérfanos (no referenciados por ningún pod) añaden desorden y pueden contener configuraciones desactualizadas o engañosas.
ES
            ;;
        *) cat <<'EN'
> **What Good Looks Like:**
> - ConfigMaps must never contain passwords, API keys, or tokens. If you find any, move them to Secrets immediately — ConfigMaps are readable by anyone with cluster access and are not designed to protect sensitive data.
> - Very large ConfigMaps (over 100 entries) suggest configuration sprawl. Break them into smaller, focused ConfigMaps — one per service or feature area — so they are easier to manage and audit.
> - Every ConfigMap should be used by at least one running application. Orphaned ConfigMaps (not referenced by any pod) add clutter and may contain outdated or misleading settings.
EN
            ;;
    esac
}

_i18n_block_wgll_secrets() {
    case "$CURRENT_LANG" in
        pt-br) cat <<'PTBR'
> **Como Deve Ser:**
> - Cada aplicação deve ter acesso apenas aos seus próprios secrets. Se o Serviço A pode ler a senha do banco de dados do Serviço B, uma violação em A também compromete B. Use namespaces do Kubernetes para impor essa separação.
> - Use o tipo correto de Secret: `kubernetes.io/dockerconfigjson` para credenciais de login do registry de containers (para baixar imagens privadas), e `Opaque` para secrets de aplicação como senhas de banco de dados e chaves de API.
> - Em produção, NÃO dependa apenas de Secrets simples do Kubernetes. Use External Secrets Operator (busca secrets de um cofre na nuvem) ou Sealed Secrets (criptografa secrets para que possam ser armazenados com segurança no Git).
> - Troque seus secrets regularmente (rotação de senhas). Uma senha que está igual há anos tem muito mais chance de ter sido vazada ou adivinhada. Quanto mais tempo uma credencial vive, mais dano uma violação pode causar.
PTBR
            ;;
        es) cat <<'ES'
> **Cómo Debería Ser:**
> - Cada aplicación solo debe tener acceso a sus propios secrets. Si el Servicio A puede leer la contraseña de la base de datos del Servicio B, una brecha en A también compromete a B. Use namespaces de Kubernetes para imponer esta separación.
> - Use el tipo correcto de Secret: `kubernetes.io/dockerconfigjson` para credenciales de inicio de sesión del registro de contenedores (para descargar imágenes privadas), y `Opaque` para secrets de aplicación como contraseñas de bases de datos y claves de API.
> - En producción, NO dependa solo de Secrets simples de Kubernetes. Use External Secrets Operator (obtiene secrets de una bóveda en la nube) o Sealed Secrets (cifra secrets para que puedan almacenarse de forma segura en Git).
> - Cambie sus secrets regularmente (rotación de contraseñas). Una contraseña que ha sido la misma durante años tiene mucha más probabilidad de haber sido filtrada o adivinada. Cuanto más tiempo vive una credencial, más daño puede causar una brecha.
ES
            ;;
        *) cat <<'EN'
> **What Good Looks Like:**
> - Each application should only have access to its own secrets. If Service A can read Service B's database password, a breach in A also compromises B. Use Kubernetes namespaces to enforce this separation.
> - Use the right Secret type: `kubernetes.io/dockerconfigjson` for container registry login credentials (to pull private images), and `Opaque` for application secrets like database passwords and API keys.
> - In production, do NOT rely on plain Kubernetes Secrets alone. Use External Secrets Operator (pulls secrets from a cloud vault) or Sealed Secrets (encrypts secrets so they can be safely stored in Git).
> - Change your secrets regularly (password rotation). A password that has been the same for years is much more likely to have been leaked or guessed. The longer a credential lives, the more damage a breach can cause.
EN
            ;;
    esac
}

_i18n_block_wgll_cluster_capacity() {
    case "$CURRENT_LANG" in
        pt-br) cat <<'PTBR'
> **Como Deve Ser:**
> - Almeje 60-80% de utilização do cluster em produção. Isso equilibra custo (não pagar por máquinas ociosas) com segurança (espaço para picos de tráfego e falhas de máquinas).
> - Abaixo de 30% de utilização significa que você está pagando por muita capacidade não utilizada. Considere remover máquinas ou usar máquinas menores para economizar custos.
> - Acima de 85% de utilização é arriscado: se uma máquina cair, as máquinas restantes podem não ter capacidade suficiente para absorver suas cargas de trabalho, causando interrupções.
> - Um cluster saudável deve ser capaz de perder 1 máquina e ainda executar tudo. Isso é chamado de redundância N-1 — planeje sua capacidade para que (total de máquinas - 1) ainda consiga lidar com a carga total.
PTBR
            ;;
        es) cat <<'ES'
> **Cómo Debería Ser:**
> - Apunte a un 60-80% de utilización del clúster en producción. Esto equilibra costo (no pagar por máquinas inactivas) con seguridad (margen para picos de tráfico y fallos de máquinas).
> - Por debajo del 30% de utilización significa que está pagando por mucha capacidad no utilizada. Considere eliminar máquinas o usar máquinas más pequeñas para ahorrar costos.
> - Por encima del 85% de utilización es riesgoso: si una máquina falla, las máquinas restantes pueden no tener suficiente capacidad para absorber sus cargas de trabajo, causando interrupciones.
> - Un clúster saludable debe ser capaz de perder 1 máquina y seguir ejecutando todo. Esto se llama redundancia N-1 — planifique su capacidad para que (total de máquinas - 1) aún pueda manejar la carga completa.
ES
            ;;
        *) cat <<'EN'
> **What Good Looks Like:**
> - Aim for 60-80% cluster utilization in production. This balances cost (not paying for idle machines) with safety (room for traffic spikes and machine failures).
> - Below 30% utilization means you are paying for a lot of unused capacity. Consider removing machines or using smaller ones to save costs.
> - Above 85% utilization is risky: if one machine goes down, the remaining machines may not have enough capacity to absorb its workloads, causing outages.
> - A healthy cluster should be able to lose 1 machine and still run everything. This is called N-1 redundancy — plan your capacity so that (total machines - 1) can still handle the full load.
EN
            ;;
    esac
}

_i18n_block_wgll_statefulsets() {
    case "$CURRENT_LANG" in
        pt-br) cat <<'PTBR'
> **Como Deve Ser:**
> - Todos os pods do StatefulSet devem mostrar Ready igual a Desired. Cada pod deve estar no estado `Running`.
> - StatefulSets atualizam pods em ordem (pod-0 primeiro, depois pod-1, depois pod-2, etc.). Se um pod falhar ao atualizar, todos os seguintes ficam travados esperando. Sempre investigue o primeiro pod travado.
> - Cada pod do StatefulSet deve ter seu próprio armazenamento (chamado PersistentVolumeClaim ou PVC) e deve mostrar como `Bound`. Se um PVC está `Pending`, o sistema de armazenamento não conseguiu criar o disco — verifique as configurações do storage class e a capacidade disponível.
> - Se você executa bancos de dados ou filas de mensagens dentro do cluster mas eles NÃO estão usando StatefulSets, considere migrar. StatefulSets dão a cada pod um nome estável e armazenamento persistente que sobrevive a reinicializações — essencial para qualquer aplicação que armazena dados.
PTBR
            ;;
        es) cat <<'ES'
> **Cómo Debería Ser:**
> - Todos los pods del StatefulSet deben mostrar Ready igual a Desired. Cada pod debe estar en estado `Running`.
> - Los StatefulSets actualizan pods en orden (pod-0 primero, luego pod-1, luego pod-2, etc.). Si un pod falla al actualizarse, todos los siguientes quedan atascados esperando. Siempre investigue el primer pod atascado.
> - Cada pod del StatefulSet debe tener su propio almacenamiento (llamado PersistentVolumeClaim o PVC) y debe mostrarse como `Bound`. Si un PVC está `Pending`, el sistema de almacenamiento no pudo crear el disco — verifique la configuración del storage class y la capacidad disponible.
> - Si ejecuta bases de datos o colas de mensajes dentro del clúster pero NO están usando StatefulSets, considere migrar. Los StatefulSets dan a cada pod un nombre estable y almacenamiento persistente que sobrevive a los reinicios — esencial para cualquier aplicación que almacena datos.
ES
            ;;
        *) cat <<'EN'
> **What Good Looks Like:**
> - All StatefulSet pods should show Ready equal to Desired. Each pod should be in the `Running` state.
> - StatefulSets update pods in order (pod-0 first, then pod-1, then pod-2, etc.). If one pod fails to update, all the ones after it are stuck waiting. Always investigate the first stuck pod.
> - Each StatefulSet pod should have its own storage (called a PersistentVolumeClaim or PVC) and it should show as `Bound`. If a PVC is `Pending`, the storage system could not create the disk — check storage class settings and available capacity.
> - If you run databases or message queues inside the cluster but they are NOT using StatefulSets, consider switching. StatefulSets give each pod a stable name and persistent storage that survives pod restarts — essential for any application that stores data.
EN
            ;;
    esac
}

_i18n_block_wgll_daemonsets() {
    case "$CURRENT_LANG" in
        pt-br) cat <<'PTBR'
> **Como Deve Ser:**
> - DaemonSets devem ter Desired igual a Ready. Se Ready for menor, algumas máquinas no cluster estão sem esta aplicação — descubra o porquê (restrições de recursos, taints de nó ou problemas de agendamento).
> - DaemonSets comuns incluem: coletores de logs (Fluentd, Fluent Bit) que coletam logs de todas as máquinas, agentes de monitoramento (OpenTelemetry, Datadog) que rastreiam o desempenho, e plugins de rede (CNI) que habilitam a comunicação entre pods.
> - Se não há DaemonSets presentes e você não tem como ver o que está acontecendo em cada máquina (sem logging ou monitoramento centralizado), considere implantar um DaemonSet do OpenTelemetry Collector. Sem ele, resolver problemas em produção é como debugar no escuro.
PTBR
            ;;
        es) cat <<'ES'
> **Cómo Debería Ser:**
> - Los DaemonSets deben tener Desired igual a Ready. Si Ready es menor, algunas máquinas del clúster no tienen esta aplicación — averigüe por qué (restricciones de recursos, taints de nodo o problemas de programación).
> - DaemonSets comunes incluyen: recolectores de logs (Fluentd, Fluent Bit) que recopilan logs de todas las máquinas, agentes de monitoreo (OpenTelemetry, Datadog) que rastrean el rendimiento, y plugins de red (CNI) que habilitan la comunicación entre pods.
> - Si no hay DaemonSets presentes y no tiene forma de ver lo que está sucediendo en cada máquina (sin logging o monitoreo centralizado), considere desplegar un DaemonSet de OpenTelemetry Collector. Sin él, resolver problemas en producción es como depurar a ciegas.
ES
            ;;
        *) cat <<'EN'
> **What Good Looks Like:**
> - DaemonSets should have Desired equal to Ready. If Ready is lower, some machines in the cluster are missing this application — find out why (resource constraints, node taints, or scheduling issues).
> - Common DaemonSets include: log collectors (Fluentd, Fluent Bit) that gather logs from every machine, monitoring agents (OpenTelemetry, Datadog) that track performance, and networking plugins (CNI) that enable pod-to-pod communication.
> - If no DaemonSets are present and you have no way to see what's happening on each machine (no centralized logging or monitoring), consider deploying an OpenTelemetry Collector DaemonSet. Without it, troubleshooting production issues is like debugging in the dark.
EN
            ;;
    esac
}

_i18n_block_wgll_replicasets() {
    case "$CURRENT_LANG" in
        pt-br) cat <<'PTBR'
> **Como Deve Ser:**
> - ReplicaSets com 0 réplicas são versões antigas da sua aplicação mantidas para que você possa reverter se necessário. Isso é completamente normal — o Kubernetes faz isso automaticamente.
> - ReplicaSets ativos (aqueles com réplicas > 0) devem sempre ter Ready igual a Desired. Uma incompatibilidade significa que alguns pods falharam ao iniciar.
> - Se você vir mais de 10 ReplicaSets antigos por deployment, significa que o Kubernetes está mantendo um histórico de versões muito longo. Você pode reduzir isso diminuindo `revisionHistoryLimit` na especificação do seu Deployment — o padrão mantém as últimas 10 versões.
PTBR
            ;;
        es) cat <<'ES'
> **Cómo Debería Ser:**
> - ReplicaSets con 0 réplicas son versiones antiguas de su aplicación que se mantienen para poder revertir si es necesario. Esto es completamente normal — Kubernetes lo hace automáticamente.
> - ReplicaSets activos (aquellos con réplicas > 0) siempre deben tener Ready igual a Desired. Una discrepancia significa que algunos pods fallaron al iniciar.
> - Si ve más de 10 ReplicaSets antiguos por deployment, significa que Kubernetes está manteniendo un historial de versiones muy largo. Puede reducirlo disminuyendo `revisionHistoryLimit` en la especificación de su Deployment — el valor predeterminado mantiene las últimas 10 versiones.
ES
            ;;
        *) cat <<'EN'
> **What Good Looks Like:**
> - ReplicaSets with 0 replicas are old versions of your app kept around so you can roll back if needed. This is completely normal — Kubernetes does this automatically.
> - Active ReplicaSets (those with replicas > 0) should always have Ready equal to Desired. A mismatch means some pods failed to start.
> - If you see more than 10 old ReplicaSets per deployment, it means Kubernetes is keeping a very long version history. You can reduce this by lowering `revisionHistoryLimit` in your Deployment spec — the default keeps the last 10 versions.
EN
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════
# K8s REPORT SUB-HEADINGS
# ═══════════════════════════════════════════════════════════════════════

_i18n_rbac_overview() {
    case "$CURRENT_LANG" in
        pt-br) echo "Visão Geral do RBAC" ;;
        es)    echo "Resumen de RBAC" ;;
        *)     echo "RBAC Overview" ;;
    esac
}

_i18n_pod_security_findings() {
    case "$CURRENT_LANG" in
        pt-br) echo "Descobertas de Segurança dos Pods" ;;
        es)    echo "Hallazgos de Seguridad de Pods" ;;
        *)     echo "Pod Security Findings" ;;
    esac
}

_i18n_network_policy_coverage() {
    case "$CURRENT_LANG" in
        pt-br) echo "Cobertura de Network Policies" ;;
        es)    echo "Cobertura de Network Policies" ;;
        *)     echo "Network Policy Coverage" ;;
    esac
}

_i18n_storageclasses() {
    case "$CURRENT_LANG" in
        pt-br) echo "StorageClasses" ;;
        es)    echo "StorageClasses" ;;
        *)     echo "StorageClasses" ;;
    esac
}

_i18n_persistent_volumes() {
    case "$CURRENT_LANG" in
        pt-br) echo "Volumes Persistentes" ;;
        es)    echo "Volúmenes Persistentes" ;;
        *)     echo "Persistent Volumes" ;;
    esac
}

_i18n_pvc_section() {
    case "$CURRENT_LANG" in
        pt-br) echo "Reivindicações de Volumes Persistentes" ;;
        es)    echo "Reclamaciones de Volúmenes Persistentes" ;;
        *)     echo "Persistent Volume Claims" ;;
    esac
}

_i18n_event_summary() {
    case "$CURRENT_LANG" in
        pt-br) echo "Resumo de Eventos" ;;
        es)    echo "Resumen de Eventos" ;;
        *)     echo "Event Summary" ;;
    esac
}

_i18n_recent_warnings() {
    case "$CURRENT_LANG" in
        pt-br) echo "Eventos de Alerta Recentes (últimos 20)" ;;
        es)    echo "Eventos de Advertencia Recientes (últimos 20)" ;;
        *)     echo "Recent Warning Events (last 20)" ;;
    esac
}

_i18n_metrics_server_status() {
    case "$CURRENT_LANG" in
        pt-br) echo "Status do Metrics Server" ;;
        es)    echo "Estado del Metrics Server" ;;
        *)     echo "Metrics Server Status" ;;
    esac
}

_i18n_services() {
    case "$CURRENT_LANG" in
        pt-br) echo "Serviços" ;;
        es)    echo "Servicios" ;;
        *)     echo "Services" ;;
    esac
}

_i18n_ingress_resources() {
    case "$CURRENT_LANG" in
        pt-br) echo "Recursos de Ingress" ;;
        es)    echo "Recursos de Ingress" ;;
        *)     echo "Ingress Resources" ;;
    esac
}

_i18n_network_policies() {
    case "$CURRENT_LANG" in
        pt-br) echo "Políticas de Rede" ;;
        es)    echo "Políticas de Red" ;;
        *)     echo "Network Policies" ;;
    esac
}

_i18n_resourcequota_coverage() {
    case "$CURRENT_LANG" in
        pt-br) echo "Cobertura de ResourceQuota" ;;
        es)    echo "Cobertura de ResourceQuota" ;;
        *)     echo "ResourceQuota Coverage" ;;
    esac
}

_i18n_limitrange_coverage() {
    case "$CURRENT_LANG" in
        pt-br) echo "Cobertura de LimitRange" ;;
        es)    echo "Cobertura de LimitRange" ;;
        *)     echo "LimitRange Coverage" ;;
    esac
}

_i18n_pdb_coverage() {
    case "$CURRENT_LANG" in
        pt-br) echo "Cobertura de PodDisruptionBudget" ;;
        es)    echo "Cobertura de PodDisruptionBudget" ;;
        *)     echo "PodDisruptionBudget Coverage" ;;
    esac
}

_i18n_image_tag_analysis() {
    case "$CURRENT_LANG" in
        pt-br) echo "Análise de Tags de Imagem" ;;
        es)    echo "Análisis de Tags de Imagen" ;;
        *)     echo "Image Tag Analysis" ;;
    esac
}

_i18n_category_scores() {
    case "$CURRENT_LANG" in
        pt-br) echo "Pontuação por Categoria" ;;
        es)    echo "Puntuación por Categoría" ;;
        *)     echo "Category Scores" ;;
    esac
}

_i18n_overall_k8s_score() {
    case "$CURRENT_LANG" in
        pt-br) echo "Pontuação Geral do K8s" ;;
        es)    echo "Puntuación General de K8s" ;;
        *)     echo "Overall K8s Score" ;;
    esac
}

_i18n_key_findings() {
    case "$CURRENT_LANG" in
        pt-br) echo "Principais Descobertas" ;;
        es)    echo "Hallazgos Principales" ;;
        *)     echo "Key Findings" ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════
# K8s REPORT CONTENT STRINGS
# ═══════════════════════════════════════════════════════════════════════

_i18n_no_resourcequotas() {
    case "$CURRENT_LANG" in
        pt-br) echo "Nenhum ResourceQuota definido nos namespaces alvo." ;;
        es)    echo "No hay ResourceQuotas definidos en los namespaces objetivo." ;;
        *)     echo "No ResourceQuotas defined in target namespaces." ;;
    esac
}

_i18n_no_limitranges() {
    case "$CURRENT_LANG" in
        pt-br) echo "Nenhum LimitRange definido nos namespaces alvo." ;;
        es)    echo "No hay LimitRanges definidos en los namespaces objetivo." ;;
        *)     echo "No LimitRanges defined in target namespaces." ;;
    esac
}

_i18n_metrics_available() {
    case "$CURRENT_LANG" in
        pt-br) echo "O Metrics Server está disponível e coletando dados." ;;
        es)    echo "El servidor de métricas está disponible y recolectando datos." ;;
        *)     echo "Metrics server is available and collecting data." ;;
    esac
}

_i18n_metrics_unavailable() {
    case "$CURRENT_LANG" in
        pt-br) echo "O Metrics Server não está disponível. Dados de utilização de recursos podem estar incompletos." ;;
        es)    echo "El servidor de métricas no está disponible. Los datos de utilización de recursos pueden estar incompletos." ;;
        *)     echo "Metrics server is not available. Resource utilization data may be incomplete." ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════
# DB REPORT HEADINGS
# ═══════════════════════════════════════════════════════════════════════

_i18n_db_external_health() {
    case "$CURRENT_LANG" in
        pt-br) echo "Saúde dos Bancos de Dados Externos" ;;
        es)    echo "Salud de las Bases de Datos Externas" ;;
        *)     echo "External Database Health" ;;
    esac
}

_i18n_db_connection_info() {
    case "$CURRENT_LANG" in
        pt-br) echo "Informações de Conexão" ;;
        es)    echo "Información de Conexión" ;;
        *)     echo "Connection Info" ;;
    esac
}

_i18n_db_key_metrics() {
    case "$CURRENT_LANG" in
        pt-br) echo "Métricas Principais" ;;
        es)    echo "Métricas Clave" ;;
        *)     echo "Key Metrics" ;;
    esac
}

_i18n_db_storage_breakdown() {
    case "$CURRENT_LANG" in
        pt-br) echo "Detalhamento de Armazenamento" ;;
        es)    echo "Desglose de Almacenamiento" ;;
        *)     echo "Storage Breakdown" ;;
    esac
}

_i18n_db_top_tables() {
    case "$CURRENT_LANG" in
        pt-br) echo "Principais Tabelas (por tamanho)" ;;
        es)    echo "Tablas Principales (por tamaño)" ;;
        *)     echo "Top Tables (by size)" ;;
    esac
}

_i18n_db_key_findings() {
    case "$CURRENT_LANG" in
        pt-br) echo "Descobertas e Recomendações" ;;
        es)    echo "Hallazgos y Recomendaciones" ;;
        *)     echo "Key Findings & Recommendations" ;;
    esac
}

_i18n_db_pg_report() {
    case "$CURRENT_LANG" in
        pt-br) echo "Relatório de Saúde do PostgreSQL" ;;
        es)    echo "Informe de Salud de PostgreSQL" ;;
        *)     echo "PostgreSQL Health Report" ;;
    esac
}

_i18n_db_mongo_report() {
    case "$CURRENT_LANG" in
        pt-br) echo "Relatório de Saúde do MongoDB" ;;
        es)    echo "Informe de Salud de MongoDB" ;;
        *)     echo "MongoDB Health Report" ;;
    esac
}

_i18n_db_valkey_report() {
    case "$CURRENT_LANG" in
        pt-br) echo "Relatório de Saúde do Valkey/Redis" ;;
        es)    echo "Informe de Salud de Valkey/Redis" ;;
        *)     echo "Valkey/Redis Health Report" ;;
    esac
}

_i18n_db_rmq_report() {
    case "$CURRENT_LANG" in
        pt-br) echo "Relatório de Saúde do RabbitMQ" ;;
        es)    echo "Informe de Salud de RabbitMQ" ;;
        *)     echo "RabbitMQ Health Report" ;;
    esac
}

_i18n_db_node_health() {
    case "$CURRENT_LANG" in
        pt-br) echo "Saúde dos Nós" ;;
        es)    echo "Salud de los Nodos" ;;
        *)     echo "Node Health" ;;
    esac
}

_i18n_db_top_queues() {
    case "$CURRENT_LANG" in
        pt-br) echo "Principais Filas" ;;
        es)    echo "Principales Colas" ;;
        *)     echo "Top Queues" ;;
    esac
}

_i18n_db_memory_breakdown() {
    case "$CURRENT_LANG" in
        pt-br) echo "Detalhamento de Memória" ;;
        es)    echo "Desglose de Memoria" ;;
        *)     echo "Memory Breakdown" ;;
    esac
}

_i18n_db_storage() {
    case "$CURRENT_LANG" in
        pt-br) echo "Armazenamento" ;;
        es)    echo "Almacenamiento" ;;
        *)     echo "Storage" ;;
    esac
}

_i18n_db_grand_unified() {
    case "$CURRENT_LANG" in
        pt-br) echo "Pontuação Unificada da Infraestrutura" ;;
        es)    echo "Puntuación Unificada de Infraestructura" ;;
        *)     echo "Grand Unified Infrastructure Score" ;;
    esac
}

_i18n_db_showing_queues() {
    case "$CURRENT_LANG" in
        pt-br) echo "por contagem de mensagens, exibindo até" ;;
        es)    echo "por cantidad de mensajes, mostrando hasta" ;;
        *)     echo "by message count, showing up to" ;;
    esac
}

_i18n_db_of() {
    case "$CURRENT_LANG" in
        pt-br) echo "de" ;;
        es)    echo "de" ;;
        *)     echo "of" ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════
# K8s PRIORITY RECOMMENDATIONS (block functions)
# ═══════════════════════════════════════════════════════════════════════

_i18n_block_recommend_nodes() {
    case "$CURRENT_LANG" in
        pt-br) printf "  - Investigar nós que não estão no estado Ready e resolver condições de pressão.\n  - Revisar utilização de recursos dos nós e considerar escalamento se consistentemente acima de 85%%.\n" ;;
        es)    printf "  - Investigar nodos que no están en estado Ready y resolver condiciones de presión.\n  - Revisar utilización de recursos de los nodos y considerar escalamiento si está consistentemente por encima del 85%%.\n" ;;
        *)     printf "  - Investigate nodes not in Ready state and resolve pressure conditions.\n  - Review node resource utilization and consider scaling if consistently above 85%%.\n" ;;
    esac
}

_i18n_block_recommend_workloads() {
    case "$CURRENT_LANG" in
        pt-br) printf "  - Corrigir deployments degradados onde réplicas prontas não correspondem à contagem desejada.\n  - Resolver pods com altas contagens de reinício e garantir que probes de saúde estejam configurados.\n" ;;
        es)    printf "  - Corregir deployments degradados donde las réplicas listas no coinciden con la cantidad deseada.\n  - Resolver pods con altas cuentas de reinicio y asegurar que los health probes estén configurados.\n" ;;
        *)     printf "  - Fix degraded deployments where ready replicas do not match desired count.\n  - Address pods with high restart counts and ensure health probes are configured.\n" ;;
    esac
}

_i18n_block_recommend_resources() {
    case "$CURRENT_LANG" in
        pt-br) printf "  - Definir requests/limits de CPU e memória em todos os containers.\n  - Revisar containers na classe QoS BestEffort e atualizar para Burstable ou Guaranteed.\n" ;;
        es)    printf "  - Establecer requests/limits de CPU y memoria en todos los contenedores.\n  - Revisar contenedores en la clase QoS BestEffort y actualizar a Burstable o Guaranteed.\n" ;;
        *)     printf "  - Set CPU and memory requests/limits on all containers.\n  - Review containers in BestEffort QoS class and upgrade to Burstable or Guaranteed.\n" ;;
    esac
}

_i18n_block_recommend_security() {
    case "$CURRENT_LANG" in
        pt-br) printf "  - Remover bindings desnecessários de cluster-admin e regras RBAC com wildcard.\n  - Eliminar containers privilegiados e aplicar runAsNonRoot.\n" ;;
        es)    printf "  - Eliminar bindings innecesarios de cluster-admin y reglas RBAC con wildcard.\n  - Eliminar contenedores privilegiados y aplicar runAsNonRoot.\n" ;;
        *)     printf "  - Remove unnecessary cluster-admin bindings and wildcard RBAC rules.\n  - Eliminate privileged containers and enforce runAsNonRoot.\n" ;;
    esac
}

_i18n_block_recommend_storage() {
    case "$CURRENT_LANG" in
        pt-br) printf "  - Investigar PVCs que não estão no estado Bound.\n  - Garantir que StorageClasses tenham políticas de recuperação apropriadas.\n" ;;
        es)    printf "  - Investigar PVCs que no están en estado Bound.\n  - Asegurar que los StorageClasses tengan políticas de recuperación apropiadas.\n" ;;
        *)     printf "  - Investigate PVCs that are not in Bound state.\n  - Ensure StorageClasses have appropriate reclaim policies.\n" ;;
    esac
}

_i18n_block_recommend_events() {
    case "$CURRENT_LANG" in
        pt-br) printf "  - Investigar eventos de alerta recorrentes e resolver causas subjacentes.\n  - Garantir que o metrics-server esteja operacional para monitoramento de recursos.\n" ;;
        es)    printf "  - Investigar eventos de advertencia recurrentes y resolver causas subyacentes.\n  - Asegurar que el metrics-server esté operacional para monitoreo de recursos.\n" ;;
        *)     printf "  - Investigate recurring warning events and resolve underlying causes.\n  - Ensure metrics-server is operational for resource monitoring.\n" ;;
    esac
}

_i18n_block_recommend_networking() {
    case "$CURRENT_LANG" in
        pt-br) printf "  - Definir NetworkPolicies para restringir tráfego entre pods.\n  - Habilitar TLS em todos os recursos de Ingress.\n" ;;
        es)    printf "  - Definir NetworkPolicies para restringir tráfico entre pods.\n  - Habilitar TLS en todos los recursos de Ingress.\n" ;;
        *)     printf "  - Define NetworkPolicies to restrict pod-to-pod traffic.\n  - Enable TLS on all Ingress resources.\n" ;;
    esac
}

_i18n_block_recommend_config() {
    case "$CURRENT_LANG" in
        pt-br) printf "  - Adicionar ResourceQuotas e LimitRanges a todos os namespaces.\n  - Criar PodDisruptionBudgets para cargas de trabalho críticas.\n  - Substituir tags de imagem :latest por versões fixas.\n" ;;
        es)    printf "  - Agregar ResourceQuotas y LimitRanges a todos los namespaces.\n  - Crear PodDisruptionBudgets para cargas de trabajo críticas.\n  - Reemplazar tags de imagen :latest con versiones fijadas.\n" ;;
        *)     printf "  - Add ResourceQuotas and LimitRanges to all namespaces.\n  - Create PodDisruptionBudgets for critical workloads.\n  - Replace :latest image tags with pinned versions.\n" ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════
# DB REPORT KEY FINDINGS STRINGS
# ═══════════════════════════════════════════════════════════════════════

_i18n_db_rmq_consumerless() {
    case "$CURRENT_LANG" in
        pt-br) echo "filas não possuem consumidores." ;;
        es)    echo "colas no tienen consumidores." ;;
        *)     echo "queues have no consumers." ;;
    esac
}

_i18n_db_rmq_consumerless_detail() {
    case "$CURRENT_LANG" in
        pt-br) echo "Mesmo que as filas possam estar vazias agora, isso é um risco latente — qualquer mensagem publicada nessas filas ficará sem processamento. Verifique se essas filas ainda são necessárias ou conecte consumidores." ;;
        es)    echo "Aunque las colas puedan estar vacías ahora, esto es un riesgo latente — cualquier mensaje publicado en estas colas quedará sin procesar. Revise si estas colas aún son necesarias o conecte consumidores." ;;
        *)     echo "Even though queues may be empty now, this is a latent risk — any message published to these queues will sit unprocessed. Review whether these queues are still needed or attach consumers." ;;
    esac
}

_i18n_db_rmq_single_node() {
    case "$CURRENT_LANG" in
        pt-br) echo "Cluster RabbitMQ de nó único." ;;
        es)    echo "Cluster RabbitMQ de nodo único." ;;
        *)     echo "Single-node RabbitMQ cluster." ;;
    esac
}

_i18n_db_rmq_single_node_detail() {
    case "$CURRENT_LANG" in
        pt-br) echo "Sem alta disponibilidade — se este nó falhar, toda a mensageria para. Considere implantar um cluster de 3 nós com filas quorum para resiliência em produção." ;;
        es)    echo "Sin alta disponibilidad — si este nodo falla, toda la mensajería se detiene. Considere implementar un cluster de 3 nodos con colas quorum para resiliencia en producción." ;;
        *)     echo "No high availability — if this node fails, all messaging stops. Consider deploying a 3-node cluster with quorum queues for production resilience." ;;
    esac
}

_i18n_db_rmq_security_low() {
    case "$CURRENT_LANG" in
        pt-br) echo "Pontuação de segurança está baixa" ;;
        es)    echo "Puntuación de seguridad es baja" ;;
        *)     echo "Security score is low" ;;
    esac
}

_i18n_db_rmq_security_detail() {
    case "$CURRENT_LANG" in
        pt-br) echo "Considere habilitar TLS para conexões de clientes, restringir o usuário guest e usar isolamento de vhost." ;;
        es)    echo "Considere habilitar TLS para conexiones de clientes, restringir el usuario guest y usar aislamiento de vhost." ;;
        *)     echo "Consider enabling TLS for client connections, restricting the guest user, and using vhost isolation." ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════
# DATABASE WGLL BLOCKS
# ═══════════════════════════════════════════════════════════════════════

_i18n_block_wgll_pg() {
    case "$CURRENT_LANG" in
        pt-br) cat <<'PTBR'
> **Como Deve Ser:**
> - **Performance:** Cache hit ratio >= 99%, uso de índices >= 95%, uso mínimo de arquivos temporários, sem deadlocks.
> - **Disponibilidade:** Utilização de conexões < 60% do máximo, mínimo de sessões idle-in-transaction, sem queries de longa duração (> 5 min).
> - **Manutenção:** Taxa de dead tuples < 5%, atividade regular de autovacuum, idade do transaction ID bem abaixo do limite de wraparound, timed checkpoints >> requested checkpoints.
> - **Replicação:** Replication lag < 1 MB, todas as réplicas conectadas e em streaming, sem replication slots inativos acumulando WAL.
> - **Utilização de Recursos:** Tamanho do banco dentro do plano de capacidade, proporção índice/heap balanceada, taxa de geração de WAL previsível.
> - **Segurança:** Sem conexões de aplicação com superuser, SSL obrigatório, autenticação por senha usando scram-sha-256, permissões PUBLIC mínimas.
> - **I/O:** Tempo médio de leitura de bloco < 1 ms, sequential scans raros em tabelas grandes, rastreamento de I/O timing habilitado.
> - **Saúde dos Índices:** Sem índices duplicados, sem índices não utilizados, todas as foreign keys indexadas.
> - **Configuração:** Parâmetros-chave ajustados para a carga de trabalho (work_mem, effective_cache_size, maintenance_work_mem), logging habilitado.
PTBR
            ;;
        es) cat <<'ES'
> **Cómo Debería Ser:**
> - **Rendimiento:** Cache hit ratio >= 99%, uso de índices >= 95%, uso mínimo de archivos temporales, sin deadlocks.
> - **Disponibilidad:** Utilización de conexiones < 60% del máximo, mínimas sesiones idle-in-transaction, sin queries de larga duración (> 5 min).
> - **Mantenimiento:** Tasa de dead tuples < 5%, actividad regular de autovacuum, edad del transaction ID bien por debajo del límite de wraparound, timed checkpoints >> requested checkpoints.
> - **Replicación:** Replication lag < 1 MB, todas las réplicas conectadas y en streaming, sin replication slots inactivos acumulando WAL.
> - **Utilización de Recursos:** Tamaño de la base de datos dentro del plan de capacidad, proporción índice/heap balanceada, tasa de generación de WAL predecible.
> - **Seguridad:** Sin conexiones de aplicación con superuser, SSL obligatorio, autenticación por contraseña usando scram-sha-256, permisos PUBLIC mínimos.
> - **E/S:** Tiempo promedio de lectura de bloque < 1 ms, sequential scans raros en tablas grandes, rastreo de I/O timing habilitado.
> - **Salud de los Índices:** Sin índices duplicados, sin índices no utilizados, todas las foreign keys indexadas.
> - **Configuración:** Parámetros clave ajustados para la carga de trabajo (work_mem, effective_cache_size, maintenance_work_mem), logging habilitado.
ES
            ;;
        *) cat <<'EN'
> **What Good Looks Like:**
> - **Performance:** Cache hit ratio >= 99%, index usage >= 95%, minimal temp file usage, no deadlocks.
> - **Availability:** Connection utilization < 60% of max, minimal idle-in-transaction sessions, no long-running queries (> 5 min).
> - **Maintenance:** Dead tuple ratio < 5%, regular autovacuum activity, transaction ID age well below wraparound threshold, timed checkpoints >> requested checkpoints.
> - **Replication:** Replication lag < 1 MB, all replicas connected and streaming, no inactive replication slots accumulating WAL.
> - **Resource Utilization:** Database size within capacity plan, index-to-heap ratio balanced, WAL generation rate predictable.
> - **Security:** No superuser application connections, SSL enforced, password authentication using scram-sha-256, minimal PUBLIC grants.
> - **I/O:** Average block read time < 1 ms, sequential scans rare on large tables, I/O timing tracking enabled.
> - **Index Health:** No duplicate indexes, no unused indexes, all foreign keys indexed.
> - **Configuration:** Key parameters tuned for workload (work_mem, effective_cache_size, maintenance_work_mem), logging enabled.
EN
            ;;
    esac
}

_i18n_block_wgll_mongo() {
    case "$CURRENT_LANG" in
        pt-br) cat <<'PTBR'
> **Como Deve Ser:**
> - **Performance:** Latência média de leitura/escrita < 1 ms, sem acúmulo de profundidade de fila, page faults próximo de zero.
> - **Replicação:** Replica set com 3+ membros, replication lag < 1 segundo, todos os secundários no estado SECONDARY, janela de oplog >= 24 horas.
> - **Recursos:** Memória residente dentro dos limites provisionados, memória virtual razoável, contagem de conexões < 50% do disponível.
> - **Armazenamento e WiredTiger:** Utilização de cache 60-80%, boas taxas de compressão, tamanho dos dados previsível e dentro do plano de capacidade.
> - **Segurança:** Autenticação habilitada, autorização aplicada (RBAC), TLS para todas as conexões, sem bancos default/test em produção.
> - **Topologia do Cluster:** Replica set distribuído adequadamente entre domínios de falha, roteamento mongos balanceado (para clusters sharded).
> - **Saúde dos Índices:** Todas as queries usando índices (sem COLLSCAN), sem índices duplicados ou não utilizados, tamanho do índice proporcional ao tamanho dos dados.
> - **Configuração:** Write concern apropriado (majority para durabilidade), read preference alinhado com a carga de trabalho, journaling habilitado.
PTBR
            ;;
        es) cat <<'ES'
> **Cómo Debería Ser:**
> - **Rendimiento:** Latencia promedio de lectura/escritura < 1 ms, sin acumulación de profundidad de cola, page faults cercanos a cero.
> - **Replicación:** Replica set con 3+ miembros, replication lag < 1 segundo, todos los secundarios en estado SECONDARY, ventana de oplog >= 24 horas.
> - **Recursos:** Memoria residente dentro de los límites aprovisionados, memoria virtual razonable, conteo de conexiones < 50% del disponible.
> - **Almacenamiento y WiredTiger:** Utilización de cache 60-80%, buenas tasas de compresión, tamaño de datos predecible y dentro del plan de capacidad.
> - **Seguridad:** Autenticación habilitada, autorización aplicada (RBAC), TLS para todas las conexiones, sin bases de datos default/test en producción.
> - **Topología del Cluster:** Replica set distribuido adecuadamente entre dominios de falla, enrutamiento mongos balanceado (para clusters sharded).
> - **Salud de los Índices:** Todas las queries usando índices (sin COLLSCAN), sin índices duplicados o no utilizados, tamaño del índice proporcional al tamaño de los datos.
> - **Configuración:** Write concern apropiado (majority para durabilidad), read preference alineado con la carga de trabajo, journaling habilitado.
ES
            ;;
        *) cat <<'EN'
> **What Good Looks Like:**
> - **Performance:** Average read/write latency < 1 ms, no queue depth buildup, page faults near zero.
> - **Replication:** Replica set with 3+ members, replication lag < 1 second, all secondaries in SECONDARY state, oplog window >= 24 hours.
> - **Resources:** Resident memory within provisioned limits, virtual memory reasonable, connection count < 50% of available.
> - **Storage & WiredTiger:** Cache utilization 60-80%, good compression ratios, data size predictable and within capacity plan.
> - **Security:** Authentication enabled, authorization enforced (RBAC), TLS for all connections, no default/test databases in production.
> - **Cluster Topology:** Properly distributed replica set across failure domains, mongos routing balanced (for sharded clusters).
> - **Index Health:** All queries using indexes (no COLLSCAN), no duplicate or unused indexes, index size proportional to data size.
> - **Configuration:** Appropriate write concern (majority for durability), read preference aligned with workload, journaling enabled.
EN
            ;;
    esac
}

_i18n_block_wgll_valkey() {
    case "$CURRENT_LANG" in
        pt-br) cat <<'PTBR'
> **Como Deve Ser:**
> - **Gerenciamento de Memória:** Memória utilizada < 75% do maxmemory, taxa de fragmentação 1.0-1.1, zero evictions em operação normal, política de eviction apropriada configurada.
> - **Performance:** Hit ratio >= 95%, latência < 1 ms (p99), zero entradas no slowlog, ops/sec consistente com a baseline.
> - **Replicação:** Réplicas conectadas com lag < 1 segundo, replication backlog dimensionado para tolerância a picos, sem eventos de resync parcial.
> - **Persistência:** Snapshots RDB concluídos com sucesso, reescrita de AOF acontecendo periodicamente sem picos de latência de fork, tempo de fork < 100 ms.
> - **Conexões:** Contagem de clientes estável, sem conexões rejeitadas, clientes bloqueados próximo de zero, uso mínimo de output buffer.
> - **Saúde do Cluster:** Todos os nós acessíveis, todos os hash slots cobertos, atividade mínima de migração, configuração consistente entre os nós.
> - **Segurança:** Autenticação obrigatória (requirepass ou ACLs), comandos perigosos renomeados/desabilitados, TLS para replicação e conexões de clientes.
> - **Configuração:** Valor de `hz` apropriado (10-100), timeout para clientes ociosos, maxmemory-policy alinhada com o caso de uso, configurações adequadas de save/AOF.
PTBR
            ;;
        es) cat <<'ES'
> **Cómo Debería Ser:**
> - **Gestión de Memoria:** Memoria utilizada < 75% del maxmemory, tasa de fragmentación 1.0-1.1, cero evictions en operación normal, política de eviction apropiada configurada.
> - **Rendimiento:** Hit ratio >= 95%, latencia < 1 ms (p99), cero entradas en el slowlog, ops/sec consistente con la baseline.
> - **Replicación:** Réplicas conectadas con lag < 1 segundo, replication backlog dimensionado para tolerancia a picos, sin eventos de resync parcial.
> - **Persistencia:** Snapshots RDB completados exitosamente, reescritura de AOF ocurriendo periódicamente sin picos de latencia de fork, tiempo de fork < 100 ms.
> - **Conexiones:** Conteo de clientes estable, sin conexiones rechazadas, clientes bloqueados cercanos a cero, uso mínimo de output buffer.
> - **Salud del Cluster:** Todos los nodos accesibles, todos los hash slots cubiertos, actividad mínima de migración, configuración consistente entre nodos.
> - **Seguridad:** Autenticación requerida (requirepass o ACLs), comandos peligrosos renombrados/deshabilitados, TLS para replicación y conexiones de clientes.
> - **Configuración:** Valor de `hz` apropiado (10-100), timeout para clientes inactivos, maxmemory-policy alineada con el caso de uso, configuraciones adecuadas de save/AOF.
ES
            ;;
        *) cat <<'EN'
> **What Good Looks Like:**
> - **Memory Management:** Used memory < 75% of maxmemory, fragmentation ratio 1.0-1.1, zero evictions in normal operation, appropriate eviction policy configured.
> - **Performance:** Hit ratio >= 95%, latency < 1 ms (p99), zero slowlog entries, ops/sec consistent with baseline.
> - **Replication:** Connected replicas with lag < 1 second, replication backlog sized for burst tolerance, no partial resync events.
> - **Persistence:** RDB snapshots completing successfully, AOF rewrite happening periodically without fork latency spikes, fork time < 100 ms.
> - **Connections:** Client count stable, no rejected connections, blocked clients near zero, output buffer usage minimal.
> - **Cluster Health:** All nodes reachable, all hash slots covered, minimal migration activity, consistent configuration across nodes.
> - **Security:** Authentication required (requirepass or ACLs), dangerous commands renamed/disabled, TLS for replication and client connections.
> - **Configuration:** Appropriate `hz` setting (10-100), timeout for idle clients, maxmemory-policy aligned with use case, proper save/AOF settings.
EN
            ;;
    esac
}

_i18n_block_wgll_rmq() {
    case "$CURRENT_LANG" in
        pt-br) cat <<'PTBR'
> **Como Deve Ser:**
> - **Saúde das Filas:** Todas as filas com consumidores ativos, profundidade das filas estável, sem crescimento descontrolado, taxa de unacked < 10% das mensagens prontas.
> - **Fluxo de Mensagens:** Taxas de publicação e entrega balanceadas, sem flow control acionado, taxas de mensagem consistentes com o throughput esperado.
> - **Recursos do Nó:** Uso de memória < 70% do limite, disco livre > 2x o limite de disco livre, uso de file descriptors < 50%, todos os nós em execução.
> - **Saúde do Cluster:** Todos os nós do cluster visíveis, partições de rede = 0, filas mirrored/quorum sincronizadas entre os nós.
> - **Conexões:** Contagem de conexões estável, sem rotatividade de conexões, canais por conexão razoáveis (< 10), sem conexões bloqueadas.
> - **Segurança:** Usuário guest padrão desabilitado ou restrito a localhost, TLS habilitado, isolamento de vhost aplicado, sem permissões excessivamente permissivas.
> - **Persistência:** Filas duráveis para mensagens importantes, lazy queues para grandes backlogs, políticas de TTL de mensagem apropriadas.
> - **Configuração:** Quorum queues preferidas sobre classic mirrored, políticas de HA adequadas, tratamento de partição de cluster configurado para autoheal ou pause_minority.
PTBR
            ;;
        es) cat <<'ES'
> **Cómo Debería Ser:**
> - **Salud de las Colas:** Todas las colas con consumidores activos, profundidad de colas estable, sin crecimiento descontrolado, tasa de unacked < 10% de los mensajes listos.
> - **Flujo de Mensajes:** Tasas de publicación y entrega balanceadas, sin flow control activado, tasas de mensajes consistentes con el throughput esperado.
> - **Recursos del Nodo:** Uso de memoria < 70% del límite, disco libre > 2x el límite de disco libre, uso de file descriptors < 50%, todos los nodos en ejecución.
> - **Salud del Cluster:** Todos los nodos del cluster visibles, particiones de red = 0, colas mirrored/quorum sincronizadas entre nodos.
> - **Conexiones:** Conteo de conexiones estable, sin rotación de conexiones, canales por conexión razonables (< 10), sin conexiones bloqueadas.
> - **Seguridad:** Usuario guest predeterminado deshabilitado o restringido a localhost, TLS habilitado, aislamiento de vhost aplicado, sin permisos excesivamente permisivos.
> - **Persistencia:** Colas durables para mensajes importantes, lazy queues para grandes backlogs, políticas de TTL de mensajes apropiadas.
> - **Configuración:** Quorum queues preferidas sobre classic mirrored, políticas de HA adecuadas, manejo de partición de cluster configurado para autoheal o pause_minority.
ES
            ;;
        *) cat <<'EN'
> **What Good Looks Like:**
> - **Queue Health:** All queues have active consumers, queue depth stable, no unbounded growth, unacked ratio < 10% of ready messages.
> - **Message Flow:** Publish and deliver rates balanced, no flow control triggered, message rates consistent with expected throughput.
> - **Node Resources:** Memory usage < 70% of limit, disk free > 2x disk free limit, file descriptor usage < 50%, all nodes running.
> - **Cluster Health:** All nodes in the cluster visible, network partitions = 0, mirrored/quorum queues in sync across nodes.
> - **Connections:** Connection count stable, no connection churn, channels per connection reasonable (< 10), no blocked connections.
> - **Security:** Default guest user disabled or restricted to localhost, TLS enabled, vhost isolation enforced, no overly permissive permissions.
> - **Persistence:** Durable queues for important messages, lazy queues for large backlogs, appropriate message TTL policies.
> - **Configuration:** Quorum queues preferred over classic mirrored, proper HA policies, cluster partition handling set to autoheal or pause_minority.
EN
            ;;
    esac
}
