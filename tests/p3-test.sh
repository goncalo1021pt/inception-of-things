#!/usr/bin/env bash
# P3 verification: k3d + Argo CD, GitOps from a public GitHub repository.
# Usage: tests/p3-test.sh [--roundtrip]
#   --roundtrip  also push v2 to the GitOps repo, wait for the app to show v2,
#                then push v1 back. This PUSHES TO GITHUB: needs push credentials
#                (e.g. `gh auth setup-git`), so it is opt-in.
set -uo pipefail

ROUNDTRIP=0
[[ "${1:-}" == "--roundtrip" ]] && ROUNDTRIP=1

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
echo "  P3 — K3d + Argo CD verification"
echo "============================================"
echo ""

echo "--- Namespaces ---"
for ns in argocd dev; do
    if kubectl get namespace "$ns" >/dev/null 2>&1; then
        pass "namespace $ns exists"
    else
        fail "namespace $ns is missing"
    fi
done

echo ""
echo "--- Argo CD ---"
ARGO_PODS=$(kubectl get pods -n argocd --no-headers 2>/dev/null || true)
for component in server repo-server application-controller; do
    LINE=$(echo "$ARGO_PODS" | grep "argocd-$component" | head -1)
    if [[ -n "$LINE" ]] && [[ "$LINE" == *"Running"* ]]; then
        pass "argocd-$component is Running"
    else
        fail "argocd-$component is not Running"
        info "${LINE:-no pod found}"
    fi
done

SOURCE=$(kubectl get application iot-app -n argocd -o jsonpath='{.spec.source.repoURL}' 2>/dev/null || true)
if [[ "$SOURCE" == https://github.com/*gfontao* ]]; then
    pass "iot-app source is a public GitHub repo with the login in its name ($SOURCE)"
else
    fail "iot-app source is not a GitHub repo containing 'gfontao'"
    info "${SOURCE:-no application}"
fi

STATE=$(kubectl get application iot-app -n argocd \
    -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null || true)
if [[ "$STATE" == "Synced/Healthy" ]]; then
    pass "iot-app is Synced/Healthy"
else
    fail "iot-app is ${STATE:-missing}, expected Synced/Healthy"
fi

echo ""
echo "--- Application ---"
READY=$(kubectl get pods -n dev --no-headers 2>/dev/null | grep -c "1/1.*Running" || true)
if [[ "$READY" -ge 1 ]]; then
    pass "playground pod Running in dev"
else
    fail "no Running playground pod in dev"
fi

IMAGE=$(kubectl get deployment playground -n dev \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
if [[ "$IMAGE" == "wil42/playground:v1" ]]; then
    pass "deployed image is $IMAGE"
else
    fail "deployed image is ${IMAGE:-missing}, expected wil42/playground:v1"
fi

RESP=$(curl -s -m 10 http://localhost:8888/ || true)
if [[ "$RESP" == *'"message": "v1"'* ]]; then
    pass "localhost:8888 answers v1"
else
    fail "localhost:8888 did not answer v1"
    info "Got: ${RESP:-nothing}"
fi

if [[ "$ROUNDTRIP" -eq 1 ]]; then
    echo ""
    echo "--- Round trip: push v2 to $SOURCE, then back to v1 ---"
    APP_PATH=$(kubectl get application iot-app -n argocd -o jsonpath='{.spec.source.path}' 2>/dev/null || true)
    WORK=$(mktemp -d)
    trap 'rm -rf "$WORK"' EXIT
    if GIT_TERMINAL_PROMPT=0 git clone -q "$SOURCE" "$WORK/repo" 2>/dev/null; then
        GIT=(git -C "$WORK/repo")
        switch() {
            local from="$1" to="$2" start waited
            sed -i "s#wil42/playground:${from}#wil42/playground:${to}#g" "$WORK/repo/$APP_PATH/deployment.yaml"
            if ! { "${GIT[@]}" commit -q -am "$to" && GIT_TERMINAL_PROMPT=0 "${GIT[@]}" push -q origin HEAD 2>/dev/null; }; then
                fail "push ${from} -> ${to}: git push failed (credentials?)"
                return 2
            fi
            start=$(date +%s)
            for _ in $(seq 90); do
                RESP=$(curl -s -m 3 http://localhost:8888/ || true)
                [[ "$RESP" == *"\"message\": \"${to}\""* ]] && break
                sleep 2
            done
            waited=$(( $(date +%s) - start ))
            if [[ "$RESP" == *"\"message\": \"${to}\""* ]]; then
                pass "push ${from} -> ${to}: app shows ${to} after ${waited}s"
            else
                fail "push ${from} -> ${to}: app still not ${to} after ${waited}s"
                return 1
            fi
        }
        # Always put the repo back to v1 once v2 was pushed (return code 2 = nothing pushed).
        switch v1 v2; rc=$?
        [[ "$rc" -ne 2 ]] && switch v2 v1
    else
        fail "could not clone $SOURCE"
    fi
fi

echo ""
echo "============================================"
echo -e "  Results: ${GREEN}${PASS} passed${NC}  ${RED}${FAIL} failed${NC}"
echo "============================================"
echo ""

[[ "$FAIL" -eq 0 ]]
