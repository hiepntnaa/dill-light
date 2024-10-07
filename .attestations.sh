#!/bin/bash

# Duong dan file log
LOG_FILE="/root/dill/attestations.log"

# Ghi log
curl -s localhost:9082/metrics | grep -E 'validator_successful_attestations' | grep pubkey >> "$LOG_FILE"
echo "Logged at: $(date)" >> "$LOG_FILE"
echo "-----------------------------" >> "$LOG_FILE"

# Lay chi so gan nhat truoc do
LAST_VALUE=$(grep -oP 'validator_successful_attestations{pubkey="[^"]+"} \K\d+' "$LOG_FILE" | tail -n 2 | head -n 1)

# Lay chi so hien tai
CURRENT_VALUE=$(grep -oP 'validator_successful_attestations{pubkey="[^"]+"} \K\d+' "$LOG_FILE" | tail -n 1)

# Kiem tra neu LAST_VALUE khong rong
if [ -z "$LAST_VALUE" ] || [ -z "$CURRENT_VALUE" ]; then
    echo "K tim thay chi so trong file log."
    exit 1
fi

# Tinh hieu so
DIFF=$((CURRENT_VALUE - LAST_VALUE))

# Kiem tra dieu kien
if [[ "$DIFF" -ge 0 ]] && [[ "$DIFF" -lt 7 ]]; then
    echo "Muc tang: $DIFF, restarting dill..."
    systemctl restart dill
else
    echo "Muc tang: $DIFF"
fi
