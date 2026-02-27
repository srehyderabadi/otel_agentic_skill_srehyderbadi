#!/usr/bin/env bash
# ==============================================================================
#  send_telemetry_demo.sh
#  Sends realistic Traces + Metrics to OTel Collector via Ingress (no port-forward)
#  Flow: curl -> localhost:80 (Traefik) -> otel-collector:4318 -> Jaeger / VictoriaMetrics
# ==============================================================================

OTEL="http://localhost:80"    # k3d cncf-hyd Traefik ingress
SERVICE="sre-hyderabadi-order-service"
ENV="k3d-demo"
ROUNDS=${1:-3}                  # pass argument to send N rounds, default 3

echo "================================================================"
echo "  🍚 SRE Hyderabadi - OTel Telemetry Demo"
echo "  Endpoint : $OTEL  (via Ingress)"
echo "  Service  : $SERVICE"
echo "  Rounds   : $ROUNDS"
echo "================================================================"
echo ""

# ---- helper: generate a random hex string ----
rand_hex() { openssl rand -hex $1 2>/dev/null || cat /dev/urandom | tr -dc 'a-f0-9' | head -c$(($1*2)); }

# ---- STEP 1: Send Traces ----
send_traces() {
  local round=$1
  local TRACE_ID=$(rand_hex 16)
  local SPAN_ID_PARENT=$(rand_hex 8)
  local SPAN_ID_CHILD=$(rand_hex 8)
  local NOW_NS=$(python3 -c "import time; print(int(time.time()*1e9))")
  local END_NS=$(python3 -c "import time; print(int(time.time()*1e9)+150000000)")

  # Determine order outcome (simulate some errors)
  local ITEM="biryani/chicken"
  local STATUS_CODE=200
  local OTEL_STATUS=1   # OK
  if [ $((round % 3)) -eq 0 ]; then
    ITEM="pizza"         # intentional 500 - not in menu!
    STATUS_CODE=500
    OTEL_STATUS=2        # ERROR
  fi

  echo "  [Trace] Round $round -> /$ITEM  (HTTP $STATUS_CODE)"

  curl -sf --max-time 5 \
    -X POST "$OTEL/v1/traces" \
    -H "Content-Type: application/json" \
    -d "{
      \"resourceSpans\": [{
        \"resource\": {
          \"attributes\": [
            {\"key\": \"service.name\",           \"value\": {\"stringValue\": \"$SERVICE\"}},
            {\"key\": \"service.version\",         \"value\": {\"stringValue\": \"1.0.0\"}},
            {\"key\": \"deployment.environment\",  \"value\": {\"stringValue\": \"$ENV\"}},
            {\"key\": \"host.name\",               \"value\": {\"stringValue\": \"order-pod-$(rand_hex 4)\"}}
          ]
        },
        \"scopeSpans\": [{
          \"scope\": {\"name\": \"opentelemetry.instrumentation.fastapi\", \"version\": \"0.44b0\"},
          \"spans\": [
            {
              \"traceId\": \"${TRACE_ID}\",
              \"spanId\": \"${SPAN_ID_PARENT}\",
              \"name\": \"GET /order/${ITEM}\",
              \"kind\": 2,
              \"startTimeUnixNano\": \"${NOW_NS}\",
              \"endTimeUnixNano\": \"${END_NS}\",
              \"attributes\": [
                {\"key\": \"http.method\",      \"value\": {\"stringValue\": \"GET\"}},
                {\"key\": \"http.route\",       \"value\": {\"stringValue\": \"/order/${ITEM}\"}},
                {\"key\": \"http.status_code\", \"value\": {\"intValue\": ${STATUS_CODE}}},
                {\"key\": \"net.peer.ip\",      \"value\": {\"stringValue\": \"10.0.0.${round}\"}}
              ],
              \"status\": {\"code\": ${OTEL_STATUS}, \"message\": \"$([ $OTEL_STATUS -eq 1 ] && echo 'OK' || echo 'Item not on menu, bhai!')\"}
            },
            {
              \"traceId\": \"${TRACE_ID}\",
              \"spanId\": \"${SPAN_ID_CHILD}\",
              \"parentSpanId\": \"${SPAN_ID_PARENT}\",
              \"name\": \"biryani.lookup\",
              \"kind\": 3,
              \"startTimeUnixNano\": \"$(python3 -c "import time; print(int(time.time()*1e9)+5000000)")\",
              \"endTimeUnixNano\": \"$(python3 -c "import time; print(int(time.time()*1e9)+80000000)")\",
              \"attributes\": [
                {\"key\": \"db.system\",     \"value\": {\"stringValue\": \"redis\"}},
                {\"key\": \"db.operation\",  \"value\": {\"stringValue\": \"GET\"}},
                {\"key\": \"db.statement\",  \"value\": {\"stringValue\": \"GET menu:${ITEM}\"}}
              ],
              \"status\": {\"code\": 1}
            }
          ]
        }]
      }]
    }" > /dev/null && echo "    ✅ trace sent (traceId=${TRACE_ID:0:16}...)" \
                  || echo "    ❌ trace failed"
}

# ---- STEP 2: Send Metrics ----
send_metrics() {
  local round=$1
  local NOW_NS=$(python3 -c "import time; print(int(time.time()*1e9))")
  local REQ_COUNT=$((round * 7 + RANDOM % 5))
  local ERR_COUNT=$((round / 3))
  local LATENCY_SUM=$(python3 -c "import random; print(round(random.uniform(120, 450), 2))")

  echo "  [Metric] Round $round -> req_count=$REQ_COUNT  errors=$ERR_COUNT  latency_sum=${LATENCY_SUM}ms"

  curl -sf --max-time 5 \
    -X POST "$OTEL/v1/metrics" \
    -H "Content-Type: application/json" \
    -d "{
      \"resourceMetrics\": [{
        \"resource\": {
          \"attributes\": [
            {\"key\": \"service.name\",          \"value\": {\"stringValue\": \"$SERVICE\"}},
            {\"key\": \"deployment.environment\", \"value\": {\"stringValue\": \"$ENV\"}}
          ]
        },
        \"scopeMetrics\": [{
          \"scope\": {\"name\": \"order-service-metrics\"},
          \"metrics\": [
            {
              \"name\": \"http_requests_total\",
              \"description\": \"Total HTTP requests handled\",
              \"unit\": \"1\",
              \"sum\": {
                \"dataPoints\": [{
                  \"startTimeUnixNano\": \"${NOW_NS}\",
                  \"timeUnixNano\": \"${NOW_NS}\",
                  \"asDouble\": ${REQ_COUNT},
                  \"attributes\": [
                    {\"key\": \"method\", \"value\": {\"stringValue\": \"GET\"}},
                    {\"key\": \"route\",  \"value\": {\"stringValue\": \"/order\"}}
                  ]
                }],
                \"aggregationTemporality\": 2,
                \"isMonotonic\": true
              }
            },
            {
              \"name\": \"http_errors_total\",
              \"description\": \"Total HTTP 5xx errors\",
              \"unit\": \"1\",
              \"sum\": {
                \"dataPoints\": [{
                  \"startTimeUnixNano\": \"${NOW_NS}\",
                  \"timeUnixNano\": \"${NOW_NS}\",
                  \"asDouble\": ${ERR_COUNT},
                  \"attributes\": [
                    {\"key\": \"status_code\", \"value\": {\"stringValue\": \"500\"}}
                  ]
                }],
                \"aggregationTemporality\": 2,
                \"isMonotonic\": true
              }
            },
            {
              \"name\": \"http_server_duration_ms\",
              \"description\": \"HTTP server request duration in ms\",
              \"unit\": \"ms\",
              \"histogram\": {
                \"dataPoints\": [{
                  \"startTimeUnixNano\": \"${NOW_NS}\",
                  \"timeUnixNano\": \"${NOW_NS}\",
                  \"count\": \"${REQ_COUNT}\",
                  \"sum\": ${LATENCY_SUM},
                  \"bucketCounts\": [\"0\",\"${ERR_COUNT}\",\"$((REQ_COUNT/2))\",\"$((REQ_COUNT/3))\",\"0\"],
                  \"explicitBounds\": [50.0, 100.0, 250.0, 500.0]
                }],
                \"aggregationTemporality\": 2
              }
            }
          ]
        }]
      }]
    }" > /dev/null && echo "    ✅ metrics sent" \
                    || echo "    ❌ metrics failed"
}

# ---- Main Loop ----
for i in $(seq 1 $ROUNDS); do
  echo ""
  echo "--- Round $i / $ROUNDS ---"
  send_traces $i
  send_metrics $i
  [ $i -lt $ROUNDS ] && sleep 1
done

echo ""
echo "================================================================"
echo "  ✅ Done! $ROUNDS rounds sent."
echo ""
echo "  📊 View in UIs — all accessible via Traefik ingress (no port-forward needed):"
echo ""
echo "     OTel Ingest      : http://localhost:80/v1/{traces,metrics,logs}"
echo "     Jaeger           : http://localhost:80/jaeger/"
echo "                        Search service: $SERVICE"
echo ""
echo "     VictoriaMetrics  : http://localhost:80/victoriametrics/vmui"
echo "                        Query: http_requests_total"
echo ""
echo "     Grafana          : http://localhost:80/grafana/  (admin/admin)"
echo "                        Add datasource: Prometheus -> http://victoriametrics.victoriametrics.svc.cluster.local:8428"
echo "                        Add datasource: Jaeger     -> http://jaeger.jaeger.svc.cluster.local:16686"
echo "================================================================"
