#!/bin/bash

# Duong dan toi file log
LOG_FILE="/root/dill/attestations.log"

# Luu log
curl -s localhost:9082/metrics | grep -E 'validator_successful_attestations' | grep pubkey >> "$LOG_FILE"
echo "Logged at: $(date)" >> "$LOG_FILE"
echo "-----------------------------" >> "$LOG_FILE"
