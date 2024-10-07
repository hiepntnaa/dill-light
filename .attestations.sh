#!/bin/bash

# Duong dan file log
LOG_FILE="/root/dill/attestations.log"

# Ghi log
echo "$(date) | $(curl -s localhost:9082/metrics | grep -E 'validator_successful_attestations' | grep pubkey)" >> "$LOG_FILE"

# Kiem tra so luong dong trong log
LINE_COUNT=$(wc -l < "$LOG_FILE")

if [ "$LINE_COUNT" -lt 2 ]; then

    exit 1
fi

# Lay chi so gan nhat truoc do
LAST_VALUE=$(grep -oP 'validator_successful_attestations{pubkey="[^"]+"} \K\d+' "$LOG_FILE" | tail -n 2 | head -n 1)


# Lay chi so hien tai
CURRENT_VALUE=$(grep -oP 'validator_successful_attestations{pubkey="[^"]+"} \K\d+' "$LOG_FILE" | tail -n 1)


# Kiem tra neu LAST_VALUE hoac CURRENT_VALUE khong trong
if [ -z "$LAST_VALUE" ] || [ -z "$CURRENT_VALUE" ]; then
    exit 1
fi

# Tinh muc tang
DIFF=$((CURRENT_VALUE - LAST_VALUE))

# Kiem tra hieu so
if [[ "$DIFF" -ge 0 ]] && [[ "$DIFF" -lt 7 ]]; then
    echo "Muc tang: $DIFF, restarting dill..."
    systemctl restart dill
else
    echo "Muc tang: $DIFF"
fi
