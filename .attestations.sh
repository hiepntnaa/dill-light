#!/bin/bash

LOG_FILE="/root/dill/attestations.log"

echo "$(date) | $(curl -s localhost:9082/metrics | grep -E 'validator_successful_attestations' | grep pubkey)" >> "$LOG_FILE"

# Kiem tra so luong dong logs
LINE_COUNT=$(wc -l < "$LOG_FILE")

if [ "$LINE_COUNT" -lt 2 ]; then
    exit 1
fi

# Lay so gan nhat truoc do
LAST_VALUE=$(grep -oP 'validator_successful_attestations{pubkey="[^"]+"} \K\d+' "$LOG_FILE" | tail -n 2 | head -n 1)

# Lay so hien tai
CURRENT_VALUE=$(grep -oP 'validator_successful_attestations{pubkey="[^"]+"} \K\d+' "$LOG_FILE" | tail -n 1)

# Kiem tra neu LAST_VALUE hoac CURRENT_VALUE khong ton tai
if [ -z "$LAST_VALUE" ] || [ -z "$CURRENT_VALUE" ]; then
    exit 1
fi

# Kiem tra neu dong ngay tren CURRENT_VALUE la "systemctl restart dill"
LAST_RESTART=$(tail -n 2 "$LOG_FILE" | grep "systemctl restart dill" | tail -n 1)

# Neu dong tren CURRENT_VALUE la "systemctl restart dill", dat LAST_VALUE = 0
if [ -n "$LAST_RESTART" ]; then
    LAST_VALUE=0
fi

# Tinh muc tang
DIFF=$((CURRENT_VALUE - LAST_VALUE))

# Kiem tra muc tang
if [[ "$DIFF" -ge 0 ]] && [[ "$DIFF" -lt 7 ]]; then
    echo "Mức tăng: $DIFF, restarting dill..."
    systemctl restart dill
    echo "systemctl restart dill" >> "$LOG_FILE"
else
    echo "Muc tang: $DIFF"
fi
