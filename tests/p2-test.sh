#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../p2"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }
info() { echo -e "${YELLOW}      ${NC} $1"; }

echo ""
echo "============================================"
echo "  P2 — K3s + Three Apps verification"
echo "============================================"
echo ""

# 1. VM running
echo "--- VM state ---"
STATUS=$(vagrant status --machine-readable 2>/dev/null)
if echo "$STATUS" | grep -q "gfontaoS,state,running"; then
    pass "gfontaoS is running"
else
    fail "gfontaoS is not running"
fi

echo ""

# 2. Node ready with correct IP
echo "--- Cluster node ---"
NODES=$(vagrant ssh gfontaoS -c "kubectl get nodes -o wide 2>/dev/null" 2>/dev/null)

if echo "$NODES" | grep -q "Ready"; then
    pass "Node is Ready"
else
    fail "Node is not Ready"
    info "$NODES"
fi

if echo "$NODES" | grep -q "192.168.56.110"; then
    pass "Node INTERNAL-IP is 192.168.56.110"
else
    fail "Node INTERNAL-IP is not 192.168.56.110"
    info "$NODES"
fi

echo ""

# 3. Pods running
echo "--- Pods ---"
PODS=$(vagrant ssh gfontaoS -c "kubectl get pods 2>/dev/null" 2>/dev/null)

APP1_READY=$(echo "$PODS" | grep "^app1" | grep -c "Running" || true)
APP2_READY=$(echo "$PODS" | grep "^app2" | grep -c "Running" || true)
APP3_READY=$(echo "$PODS" | grep "^app3" | grep -c "Running" || true)

if [[ "$APP1_READY" -eq 1 ]]; then
    pass "app1: 1 pod Running"
else
    fail "app1: expected 1 Running pod, got $APP1_READY"
fi

if [[ "$APP2_READY" -eq 3 ]]; then
    pass "app2: 3 pods Running (replicas OK)"
else
    fail "app2: expected 3 Running pods, got $APP2_READY"
fi

if [[ "$APP3_READY" -eq 1 ]]; then
    pass "app3: 1 pod Running"
else
    fail "app3: expected 1 Running pod, got $APP3_READY"
fi

echo ""

# 4. Ingress exists
echo "--- Ingress ---"
INGRESS=$(vagrant ssh gfontaoS -c "kubectl get ingress 2>/dev/null" 2>/dev/null)
if echo "$INGRESS" | grep -q "p2-ingress"; then
    pass "Ingress resource exists"
else
    fail "Ingress resource not found"
    info "$INGRESS"
fi

echo ""

# 5. Routing via curl (single SSH session — mirrors subject's curl examples from inside the VM)
echo "--- Routing ---"
ROUTES=$(vagrant ssh gfontaoS -c "
    echo '---APP1---'
    curl -s -H 'Host: app1.com' http://192.168.56.110
    echo '---APP2---'
    curl -s -H 'Host: app2.com' http://192.168.56.110
    echo '---APP3---'
    curl -s http://192.168.56.110
" 2>/dev/null || true)

APP1_RESP=$(echo "$ROUTES" | sed -n '/---APP1---/,/---APP2---/p')
APP2_RESP=$(echo "$ROUTES" | sed -n '/---APP2---/,/---APP3---/p')
APP3_RESP=$(echo "$ROUTES" | sed -n '/---APP3---/,$p')

if echo "$APP1_RESP" | grep -q "Hello from app1"; then
    pass "Host: app1.com  → serves app1"
else
    fail "Host: app1.com  → did not receive app1 response"
    info "Got: $(echo "$APP1_RESP" | grep -v '^---' | head -3)"
fi

if echo "$APP2_RESP" | grep -q "Hello from app2"; then
    pass "Host: app2.com  → serves app2"
else
    fail "Host: app2.com  → did not receive app2 response"
    info "Got: $(echo "$APP2_RESP" | grep -v '^---' | head -3)"
fi

if echo "$APP3_RESP" | grep -q "Hello from app3"; then
    pass "Host: (other)   → serves app3 (default)"
else
    fail "Host: (other)   → did not receive app3 response"
    info "Got: $(echo "$APP3_RESP" | grep -v '^---' | head -3)"
fi

echo ""

# 6. Routing from the host machine (what the evaluator does during defense)
echo "--- Routing from host ---"
host_route() {
    local expected="$1"; shift
    local label="$1"; shift
    local resp
    resp=$(curl -s -m 10 -w '\nHTTP_CODE=%{http_code}' "$@" http://192.168.56.110 || true)
    if [[ "$resp" == *"Hello from $expected"* ]]; then
        pass "host: $label → serves $expected"
    else
        fail "host: $label → did not receive $expected response"
        info "$(echo "$resp" | grep -oE 'Hello from app[0-9]|HTTP_CODE=[0-9]+|404 page not found' | tr '\n' ' ')"
    fi
}
host_route app1 "Host: app1.com" -H "Host: app1.com"
host_route app2 "Host: app2.com" -H "Host: app2.com"
host_route app3 "(no Host)     "
host_route app3 "Host: foo.com " -H "Host: foo.com"

echo ""
echo "============================================"
echo -e "  Results:${GREEN}${PASS} passed${NC}  ${RED}${FAIL} failed${NC}"
echo "============================================"
echo ""

[[ "$FAIL" -eq 0 ]]
