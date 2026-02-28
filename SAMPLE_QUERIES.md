# Observability Sample Queries

This guide provides instructions and sample PromQL queries to verify your metrics in **Grafana**, **VictoriaMetrics**, and **Prometheus**.

---

## 1. Accessing the UIs

### 📊 Grafana

Grafana is exposed via the Traefik Ingress. You can access it directly at:

- **URL**: [http://localhost:80/grafana](http://localhost:80/grafana)
- **Data Sources**: `VictoriaMetrics` and `Prometheus` are pre-configured. Switch the datasource in the Explore tab depending on which OTel profile is active.

### 📈 VictoriaMetrics (Independent UI)

VictoriaMetrics provides a built-in UI called `vmui`. Since it's not exposed via Ingress, you need to port-forward to access it safely.

1. **Port-forward the service:**
   ```bash
   kubectl port-forward -n victoriametrics svc/victoriametrics 8428:8428
   ```
2. **Access the UI:** Open [http://localhost:8428/vmui/](http://localhost:8428/vmui/) in your browser.
3. Keep the terminal running as long as you need to use the UI.

### 🔍 Prometheus (Independent UI)

Similarly, the Prometheus UI is internal to the cluster.

1. **Port-forward the service:**
   ```bash
   kubectl port-forward -n prometheus svc/prometheus 9090:9090
   ```
2. **Access the UI:** Open [http://localhost:9090/](http://localhost:9090/) in your browser.
3. Keep the terminal open to maintain the connection.

> **Note:** Metrics will only flow to Prometheus if you have switched to the `demo` profile using `/switch-otel-config demo`. By default (`initial` profile), metrics flow to VictoriaMetrics.

---

## 2. Sample PromQL Queries

You can run these queries in **Grafana** (Explore view), **VictoriaMetrics UI**, or **Prometheus UI**. The metrics are generated automatically by OpenTelemetry Python auto-instrumentation.

### Application Traffic & Errors

**1. Total HTTP Requests across all services**

```promql
sum(rate(http_server_request_duration_seconds_count[5m]))
```

_(If your OTel version uses milliseconds, replace `\_seconds_`with`_milliseconds_`)\_

**2. HTTP Requests grouped by Target Service**

```promql
sum(rate(http_server_request_duration_seconds_count[5m])) by (job)
```

**3. Application Error Rate (HTTP 5xx responses)**

```promql
sum(rate(http_server_request_duration_seconds_count{http_response_status_code=~"5.."}[5m])) by (job)
```

### Specific Service Metrics

**4. Total Requests for `order-service`**

```promql
sum(rate(http_server_request_duration_seconds_count{job="order-service"}[5m]))
```

**5. `order-service` Requests grouped by HTTP Status Code**

```promql
sum(rate(http_server_request_duration_seconds_count{job="order-service"}[5m])) by (http_response_status_code)
```

### Application Latency

**6. Average Request Duration (Latency)**

```promql
sum(rate(http_server_request_duration_seconds_sum[5m])) / sum(rate(http_server_request_duration_seconds_count[5m]))
```

**7. 95th Percentile Latency by Service**

```promql
histogram_quantile(0.95, sum(rate(http_server_request_duration_seconds_bucket[5m])) by (le, job))
```

### Infrastructure / Process Metrics

**8. Active HTTP Requests**

```promql
sum(http_server_active_requests) by (job)
```

**9. CPU Usage per microservice**

```promql
rate(process_cpu_seconds_total[5m])
```

**10. Memory Usage (RSS) per microservice**

```promql
process_memory_usage
```

_(Note: Process metrics might slightly vary based on python instrumentation flags)_

---

## 3. Testing with Load

To see these queries light up with data, generate some artificial traffic using the provided k6 scripts.

1. Start the healthy load:
   ```bash
   ./run_k6.sh
   # (Select option 1 for Healthy load)
   ```
2. Run the queries in Grafana/VM/Prometheus to see the `http_server_request_duration_seconds_count` climb.
3. Let it run for 1-2 minutes to populate the rate queries over time.
