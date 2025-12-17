# Coder Observability Helm Values Template
# Production configuration for Coder observability stack
#
# Requirements covered:
# - 8.1a: Prometheus metrics export (port 2112)
# - 8.1b: Optional AMP/CloudWatch Container Insights integration
# - 8.1c: Grafana dashboards for Coder-specific metrics
# - 15.2a: Opinionated values file for observability components
# - 14.13: API latency monitoring (P95, P99)
# - 14.20: Scaling delay alerts
#
# Key Metrics Exported:
# - coderd_api_request_latencies_seconds: API request latency histogram
# - coderd_workspace_builds_total: Workspace build counter by status
# - coderd_workspaces_current: Current workspace count by status
# - coderd_provisioner_jobs_current: Active provisioner jobs
# - coderd_db_connections_*: Database connection pool metrics
# - coderd_workspace_build_duration_seconds: Workspace provisioning time

# =============================================================================
# Prometheus Configuration
# Requirement 8.1a: Prometheus metrics export
# =============================================================================

prometheus:
  enabled: ${enable_prometheus}
  
  # ServiceMonitor for Prometheus Operator
  # Creates a ServiceMonitor CR that tells Prometheus to scrape Coder metrics
  serviceMonitor:
    enabled: ${enable_service_monitor}
    namespace: ${prometheus_namespace}
    interval: ${scrape_interval}
    scrapeTimeout: ${scrape_timeout}
    labels:
      release: prometheus
      app: coder
    
    # Metric relabeling for CloudWatch Container Insights compatibility
    metricRelabelings:
      - sourceLabels: [__name__]
        regex: 'coderd_.*'
        action: keep
    
    # Additional labels to add to all metrics
    relabelings:
      - sourceLabels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
        targetLabel: app
      - sourceLabels: [__meta_kubernetes_namespace]
        targetLabel: namespace

# =============================================================================
# Coder Metrics Configuration
# These environment variables are merged with coder-values.yaml
# =============================================================================

coder:
  env:
    # Enable Prometheus metrics endpoint
    - name: CODER_PROMETHEUS_ENABLE
      value: "true"
    
    # Prometheus metrics listen address
    - name: CODER_PROMETHEUS_ADDRESS
      value: "0.0.0.0:2112"
    
    # Enable detailed agent/workspace metrics
    - name: CODER_PROMETHEUS_COLLECT_AGENT_STATS
      value: "${collect_agent_stats}"
    
    # Enable database connection pool metrics
    - name: CODER_PROMETHEUS_COLLECT_DB_METRICS
      value: "${collect_db_metrics}"


# =============================================================================
# Amazon Managed Prometheus (AMP) Integration
# Requirement 8.1b: Optional AMP integration for centralized metrics
# =============================================================================

%{ if enable_amp_integration ~}
remoteWrite:
  enabled: true
  url: "${amp_remote_write_url}"
  sigv4:
    enabled: true
    region: ${aws_region}
  queueConfig:
    maxSamplesPerSend: 1000
    maxShards: 200
    capacity: 2500
  writeRelabelConfigs:
    # Only send Coder-specific metrics to AMP
    - sourceLabels: [__name__]
      regex: 'coderd_.*|coder_.*'
      action: keep
%{ endif ~}

# =============================================================================
# CloudWatch Container Insights Integration
# Requirement 8.1b: Optional CloudWatch Container Insights integration
# =============================================================================

%{ if enable_container_insights ~}
cloudwatch:
  enabled: true
  namespace: "Coder/${environment}"
  region: ${aws_region}
  
  # Metrics to export to CloudWatch
  # These align with the CloudWatch dashboards created in observability module
  metrics:
    # API Performance Metrics (Requirements 14.9, 14.10)
    - name: "coderd_api_request_latencies_seconds"
      dimensions:
        - method
        - path
      statistic: p95
    - name: "coderd_api_request_latencies_seconds"
      dimensions:
        - method
        - path
      statistic: p99
    
    # Workspace Metrics
    - name: "coderd_workspace_builds_total"
      dimensions:
        - status
        - template
    - name: "coderd_workspaces_current"
      dimensions:
        - status
    - name: "coderd_workspace_build_duration_seconds"
      dimensions:
        - template
      statistic: p95
    
    # Provisioner Metrics
    - name: "coderd_provisioner_jobs_current"
      dimensions:
        - status
        - provisioner
    
    # Database Metrics
    - name: "coderd_db_connections_open"
    - name: "coderd_db_connections_in_use"
    - name: "coderd_db_connections_idle"
%{ endif ~}

# =============================================================================
# Grafana Dashboards
# Requirement 8.1c: Pre-configured Grafana dashboards
# =============================================================================

grafana:
  enabled: ${enable_grafana_dashboards}
  
  # Dashboard ConfigMaps for Grafana sidecar
  dashboardsConfigMaps:
    coder: coder-dashboards
  
  dashboards:
    # Coder Platform Overview Dashboard
    coder-overview:
      json: |
        {
          "title": "Coder Platform Overview",
          "uid": "coder-overview",
          "tags": ["coder", "overview"],
          "timezone": "browser",
          "refresh": "30s",
          "panels": [
            {
              "title": "Active Workspaces",
              "type": "stat",
              "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0},
              "targets": [
                {"expr": "sum(coderd_workspaces_current{status=\"running\"})"}
              ],
              "fieldConfig": {
                "defaults": {"thresholds": {"steps": [{"color": "green", "value": null}]}}
              }
            },
            {
              "title": "Total Users",
              "type": "stat",
              "gridPos": {"h": 4, "w": 6, "x": 6, "y": 0},
              "targets": [
                {"expr": "coderd_users_total"}
              ]
            },
            {
              "title": "API Latency P95",
              "type": "gauge",
              "gridPos": {"h": 4, "w": 6, "x": 12, "y": 0},
              "targets": [
                {"expr": "histogram_quantile(0.95, sum(rate(coderd_api_request_latencies_seconds_bucket[5m])) by (le))"}
              ],
              "fieldConfig": {
                "defaults": {
                  "unit": "s",
                  "thresholds": {
                    "steps": [
                      {"color": "green", "value": null},
                      {"color": "yellow", "value": 0.3},
                      {"color": "red", "value": 0.5}
                    ]
                  },
                  "max": 1
                }
              }
            },
            {
              "title": "API Latency P99",
              "type": "gauge",
              "gridPos": {"h": 4, "w": 6, "x": 18, "y": 0},
              "targets": [
                {"expr": "histogram_quantile(0.99, sum(rate(coderd_api_request_latencies_seconds_bucket[5m])) by (le))"}
              ],
              "fieldConfig": {
                "defaults": {
                  "unit": "s",
                  "thresholds": {
                    "steps": [
                      {"color": "green", "value": null},
                      {"color": "yellow", "value": 0.5},
                      {"color": "red", "value": 1}
                    ]
                  },
                  "max": 2
                }
              }
            },
            {
              "title": "Workspace Builds Over Time",
              "type": "timeseries",
              "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4},
              "targets": [
                {"expr": "sum(rate(coderd_workspace_builds_total[5m])) by (status)", "legendFormat": "{{status}}"}
              ]
            },
            {
              "title": "Provisioner Jobs",
              "type": "timeseries",
              "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4},
              "targets": [
                {"expr": "sum(coderd_provisioner_jobs_current) by (status)", "legendFormat": "{{status}}"}
              ]
            }
          ]
        }
    
    # Coder Performance Dashboard
    coder-performance:
      json: |
        {
          "title": "Coder Performance",
          "uid": "coder-performance",
          "tags": ["coder", "performance"],
          "timezone": "browser",
          "refresh": "30s",
          "panels": [
            {
              "title": "API Latency Distribution",
              "type": "heatmap",
              "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
              "targets": [
                {"expr": "sum(rate(coderd_api_request_latencies_seconds_bucket[5m])) by (le)"}
              ]
            },
            {
              "title": "Database Connection Pool",
              "type": "timeseries",
              "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
              "targets": [
                {"expr": "coderd_db_connections_open", "legendFormat": "Open"},
                {"expr": "coderd_db_connections_in_use", "legendFormat": "In Use"},
                {"expr": "coderd_db_connections_idle", "legendFormat": "Idle"}
              ]
            },
            {
              "title": "Workspace Provisioning Time P95 (Pod)",
              "type": "gauge",
              "gridPos": {"h": 4, "w": 6, "x": 0, "y": 8},
              "targets": [
                {"expr": "histogram_quantile(0.95, sum(rate(coderd_workspace_build_duration_seconds_bucket{template=~\"pod-.*\"}[1h])) by (le))"}
              ],
              "fieldConfig": {
                "defaults": {
                  "unit": "s",
                  "thresholds": {
                    "steps": [
                      {"color": "green", "value": null},
                      {"color": "yellow", "value": 90},
                      {"color": "red", "value": 120}
                    ]
                  },
                  "max": 180
                }
              }
            },
            {
              "title": "Workspace Provisioning Time P95 (EC2)",
              "type": "gauge",
              "gridPos": {"h": 4, "w": 6, "x": 6, "y": 8},
              "targets": [
                {"expr": "histogram_quantile(0.95, sum(rate(coderd_workspace_build_duration_seconds_bucket{template=~\"ec2-.*\"}[1h])) by (le))"}
              ],
              "fieldConfig": {
                "defaults": {
                  "unit": "s",
                  "thresholds": {
                    "steps": [
                      {"color": "green", "value": null},
                      {"color": "yellow", "value": 240},
                      {"color": "red", "value": 300}
                    ]
                  },
                  "max": 360
                }
              }
            }
          ]
        }


# =============================================================================
# Alerting Rules
# Requirements: 14.13 (API latency monitoring), 14.20 (scaling delay alerts)
# =============================================================================

alerting:
  enabled: ${enable_alerting}
  
  # PrometheusRule CR for Prometheus Operator
  prometheusRule:
    enabled: ${enable_alerting}
    namespace: ${prometheus_namespace}
    labels:
      release: prometheus
    
  rules:
    # =========================================================================
    # API Latency Alerts
    # Requirements: 14.9 (P95 < 500ms), 14.10 (P99 < 1s)
    # =========================================================================
    - alert: CoderAPILatencyP95High
      expr: histogram_quantile(0.95, sum(rate(coderd_api_request_latencies_seconds_bucket[5m])) by (le)) > 0.5
      for: 5m
      labels:
        severity: warning
        team: platform
      annotations:
        summary: "Coder API P95 latency exceeds 500ms threshold"
        description: "P95 API latency is {{ $value | humanizeDuration }} (threshold: 500ms)"
        runbook_url: "https://coder.com/docs/admin/monitoring#api-latency"
    
    - alert: CoderAPILatencyP99Critical
      expr: histogram_quantile(0.99, sum(rate(coderd_api_request_latencies_seconds_bucket[5m])) by (le)) > 1
      for: 5m
      labels:
        severity: critical
        team: platform
      annotations:
        summary: "Coder API P99 latency exceeds 1s threshold"
        description: "P99 API latency is {{ $value | humanizeDuration }} (threshold: 1s)"
        runbook_url: "https://coder.com/docs/admin/monitoring#api-latency"
    
    # =========================================================================
    # Workspace Provisioning Alerts
    # Requirements: 14.6 (pod < 2min), 14.7 (EC2 < 5min)
    # =========================================================================
    - alert: CoderPodWorkspaceProvisioningSlow
      expr: histogram_quantile(0.95, sum(rate(coderd_workspace_build_duration_seconds_bucket{template=~"pod-.*"}[1h])) by (le)) > 120
      for: 15m
      labels:
        severity: warning
        team: platform
      annotations:
        summary: "Pod workspace provisioning exceeds 2 minute threshold"
        description: "P95 pod workspace provisioning time is {{ $value | humanizeDuration }}"
        runbook_url: "https://coder.com/docs/admin/monitoring#workspace-provisioning"
    
    - alert: CoderEC2WorkspaceProvisioningSlow
      expr: histogram_quantile(0.95, sum(rate(coderd_workspace_build_duration_seconds_bucket{template=~"ec2-.*"}[1h])) by (le)) > 300
      for: 15m
      labels:
        severity: warning
        team: platform
      annotations:
        summary: "EC2 workspace provisioning exceeds 5 minute threshold"
        description: "P95 EC2 workspace provisioning time is {{ $value | humanizeDuration }}"
        runbook_url: "https://coder.com/docs/admin/monitoring#workspace-provisioning"
    
    # =========================================================================
    # Scaling Alerts
    # Requirement 14.20: Scaling delays generate operational alerts
    # =========================================================================
    - alert: CoderScalingDelayed
      expr: (time() - coderd_last_scale_event_timestamp) > 300 and coderd_pending_workspace_builds > 0
      for: 5m
      labels:
        severity: warning
        team: platform
      annotations:
        summary: "Workspace scaling delayed beyond 5 minute threshold"
        description: "{{ $value }} workspaces pending with no recent scaling event"
        runbook_url: "https://coder.com/docs/admin/monitoring#scaling"
    
    # =========================================================================
    # Provisioner Health Alerts
    # =========================================================================
    - alert: CoderNoActiveProvisioners
      expr: sum(coderd_provisioner_jobs_current{status="running"}) == 0 and sum(coderd_provisioner_jobs_current{status="pending"}) > 0
      for: 5m
      labels:
        severity: critical
        team: platform
      annotations:
        summary: "No active provisioners with pending jobs"
        description: "{{ $value }} jobs pending but no provisioners are processing"
        runbook_url: "https://coder.com/docs/admin/provisioners#troubleshooting"
    
    - alert: CoderProvisionerJobsBacklog
      expr: sum(coderd_provisioner_jobs_current{status="pending"}) > 10
      for: 10m
      labels:
        severity: warning
        team: platform
      annotations:
        summary: "Provisioner job backlog growing"
        description: "{{ $value }} provisioner jobs pending"
        runbook_url: "https://coder.com/docs/admin/provisioners#scaling"
    
    # =========================================================================
    # Database Health Alerts
    # =========================================================================
    - alert: CoderDatabaseConnectionPoolExhausted
      expr: coderd_db_connections_in_use / coderd_db_connections_open > 0.9
      for: 5m
      labels:
        severity: warning
        team: platform
      annotations:
        summary: "Database connection pool near exhaustion"
        description: "{{ $value | humanizePercentage }} of database connections in use"
        runbook_url: "https://coder.com/docs/admin/monitoring#database"
    
    # =========================================================================
    # Workspace Health Alerts
    # =========================================================================
    - alert: CoderHighWorkspaceFailureRate
      expr: sum(rate(coderd_workspace_builds_total{status="failed"}[1h])) / sum(rate(coderd_workspace_builds_total[1h])) > 0.1
      for: 15m
      labels:
        severity: warning
        team: platform
      annotations:
        summary: "High workspace build failure rate"
        description: "{{ $value | humanizePercentage }} of workspace builds failing"
        runbook_url: "https://coder.com/docs/admin/monitoring#workspace-failures"
