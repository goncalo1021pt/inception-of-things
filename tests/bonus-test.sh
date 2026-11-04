#!/usr/bin/env bash
# Bonus verification: GitLab in namespace "gitlab" is the Git source of Argo CD.
# Usage: tests/bonus-test.sh [--roundtrip]
#   --roundtrip  also push v2 to GitLab, wait for the app to show v2, then push v1 back
set -uo pipefail

GITLAB_HOST="${GITLAB_HOST:-gitlab.localhost}"
GITLAB_PROJECT="${GITLAB_PROJECT:-root/gfontao-iot}"
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
echo "  Bonus — GitLab + Argo CD verification"
echo "============================================"
echo ""

echo "--- Namespaces ---"
for ns in gitlab argocd dev; do
    if kubectl get namespace "$ns" >/dev/null 2>&1; then
        pass "namespace $ns exists"
    else
        fail "namespace $ns is missing"
    fi
done

echo ""
echo "--- GitLab workloads (namespace gitlab) ---"
PODS=$(kubectl get pods -n gitlab --no-headers 2>/dev/null || true)
for component in webservice gitaly postgresql redis sidekiq; do
    LINE=$(echo "$PODS" | grep "$component" | grep -v -E 'Completed|migrations' | head -1)
    if [[ -n "$LINE" ]] && echo "$LINE" | grep -q "Running"; then
        pass "gitlab $component is Running"
    else
        fail "gitlab $component is not Running"
        info "${LINE:-no pod found}"
    fi
done

echo ""
echo "--- GitLab from the host ---"
CODE=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "http://${GITLAB_HOST}/users/sign_in" || true)
if [[ "$CODE" == "200" ]]; then
    pass "http://${GITLAB_HOST}/users/sign_in answers 200"
else
    fail "http://${GITLAB_HOST}/users/sign_in answered ${CODE:-nothing}"
fi

PASSWORD=$(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab \
    -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode || true)
AUTH_URL="http://root:${PASSWORD}@${GITLAB_HOST}/${GITLAB_PROJECT}.git"
if [[ -n "$PASSWORD" ]] && git ls-remote "$AUTH_URL" HEAD 2>/dev/null | grep -q .; then
    pass "project ${GITLAB_PROJECT} exists and has commits"
else
    fail "project ${GITLAB_PROJECT} not reachable with the root password"
fi

if git ls-remote "http://${GITLAB_HOST}/${GITLAB_PROJECT}.git" HEAD </dev/null >/dev/null 2>&1; then
    fail "project is readable without credentials (expected private)"
else
    pass "project is private (anonymous access refused)"
fi

echo ""
echo "--- Argo CD application ---"
SOURCE=$(kubectl get application iot-app -n argocd -o jsonpath='{.spec.source.repoURL}' 2>/dev/null || true)
if [[ "$SOURCE" == *"gitlab"* && "$SOURCE" != *"github"* ]]; then
    pass "iot-app source is GitLab ($SOURCE)"
else
    fail "iot-app source is not GitLab"
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

RESP=$(curl -s -m 10 http://localhost:8888/ || true)
if [[ "$RESP" == *'"message": "v1"'* ]]; then
    pass "localhost:8888 answers v1"
else
    fail "localhost:8888 did not answer v1"
    info "Got: ${RESP:-nothing}"
fi

if [[ "$ROUNDTRIP" -eq 1 ]]; then
    echo ""
    echo "--- Round trip: push v2 to GitLab, then back to v1 ---"
    WORK=$(mktemp -d)
    trap 'rm -rf "$WORK"' EXIT
    if git clone -q "$AUTH_URL" "$WORK/repo" 2>/dev/null; then
        GIT=(git -C "$WORK/repo" -c user.name=gfontao -c user.email=gfontao@localhost)
        switch() {
            local from="$1" to="$2" start waited
            sed -i "s#wil42/playground:${from}#wil42/playground:${to}#g" "$WORK/repo/manifests/deployment.yaml"
            "${GIT[@]}" commit -q -am "$to" && "${GIT[@]}" push -q origin HEAD 2>/dev/null
            start=$(date +%s)
            for _ in $(seq 90); do
                RESP=$(curl -s -m 3 http://localhost:8888/ || true)
                [[ "$RESP" == *"\"message\": \"${to}\""* ]] && break
                sleep 2
            done
            waited=$(( $(date +%s) - start ))
            if [[ "$RESP" == *"\"message\": \"${to}\""* ]]; then
                pass "push ${from} -> ${to} to GitLab: app shows ${to} after ${waited}s"
            else
                fail "push ${from} -> ${to} to GitLab: app still not ${to} after ${waited}s"
            fi
        }
        switch v1 v2
        switch v2 v1
    else
        fail "could not clone ${GITLAB_PROJECT} from GitLab"
    fi
fi

echo ""
echo "============================================"
echo -e "  Results: ${GREEN}${PASS} passed${NC}  ${RED}${FAIL} failed${NC}"
echo "============================================"
echo ""

[[ "$FAIL" -eq 0 ]]
