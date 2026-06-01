#!/usr/bin/env bash
set -euo pipefail

IP="192.168.56.110"
DOMAINS=("app1.com" "app2.com" "app3.com")

for domain in "${DOMAINS[@]}"; do
    if grep -qF "$domain" /etc/hosts; then
        echo "  already set: $domain"
    else
        echo "$IP  $domain" | sudo tee -a /etc/hosts > /dev/null
        echo "  added: $domain → $IP"
    fi
done
