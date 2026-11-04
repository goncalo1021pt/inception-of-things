#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../p1"

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
echo "  P1 — K3s + Vagrant verification"
echo "============================================"
echo ""

# 1. Both VMs running
echo "--- VM state ---"
STATUS=$(vagrant status --machine-readable 2>/dev/null)

if echo "$STATUS" | grep -q "gfontaoS,state,running"; then
    pass "gfontaoS is running"
else
    fail "gfontaoS is not running"
fi

if echo "$STATUS" | grep -q "gfontaoSW,state,running"; then
    pass "gfontaoSW is running"
else
    fail "gfontaoSW is not running"
fi

echo ""

# 2. SSH without password
echo "--- SSH (no password) ---"
if vagrant ssh gfontaoS -c "echo ok" &>/dev/null; then
    pass "SSH into gfontaoS works without password"
else
    fail "SSH into gfontaoS failed"
fi

if vagrant ssh gfontaoSW -c "echo ok" &>/dev/null; then
    pass "SSH into gfontaoSW works without password"
else
    fail "SSH into gfontaoSW failed"
fi

echo ""

# 3. Cluster node checks (single kubectl call, reused for all checks)
echo "--- Cluster nodes ---"
NODES=$(vagrant ssh gfontaoS -c "kubectl get nodes -o wide 2>/dev/null" 2>/dev/null)

READY_COUNT=$(echo "$NODES" | grep -c " Ready " || true)
if [[ "$READY_COUNT" -eq 2 ]]; then
    pass "Both nodes are Ready ($READY_COUNT/2)"
else
    fail "Expected 2 Ready nodes, got $READY_COUNT"
    info "kubectl get nodes -o wide output:"
    echo "$NODES" | sed 's/^/      /'
fi

if echo "$NODES" | grep -q "gfontaos.*control-plane"; then
    pass "gfontaos has role: control-plane"
else
    fail "gfontaos does not have control-plane role"
    info "Actual output:"
    echo "$NODES" | grep "^gfontaos " | sed 's/^/      /' || true
fi

if echo "$NODES" | grep "gfontaosw" | grep -qv "control-plane"; then
    pass "gfontaosw has role: <none> (agent)"
else
    fail "gfontaosw unexpectedly has a control-plane role"
fi

if echo "$NODES" | grep -q "192.168.56.110"; then
    pass "gfontaos INTERNAL-IP is 192.168.56.110"
else
    fail "gfontaos INTERNAL-IP is not 192.168.56.110"
    info "Actual IPs:"
    echo "$NODES" | awk 'NR>1 {print $1, $6}' | sed 's/^/      /' || true
fi

if echo "$NODES" | grep -q "192.168.56.111"; then
    pass "gfontaosw INTERNAL-IP is 192.168.56.111"
else
    fail "gfontaosw INTERNAL-IP is not 192.168.56.111"
fi

echo ""

# 4. Worker NIC
echo "--- Network interfaces ---"
ETH1=$(vagrant ssh gfontaoSW -c "ip a show eth1 2>/dev/null" 2>/dev/null)

if echo "$ETH1" | grep -q "192.168.56.111"; then
    pass "gfontaoSW eth1 has inet 192.168.56.111"
else
    fail "gfontaoSW eth1 does not have 192.168.56.111"
    info "eth1 output:"
    echo "$ETH1" | sed 's/^/      /' || true
fi

echo ""
echo "============================================"
echo -e "  Results: ${GREEN}${PASS} passed${NC}  ${RED}${FAIL} failed${NC}"
echo "============================================"
echo ""

[[ "$FAIL" -eq 0 ]]
