#!/bin/bash

# Đặt địa chỉ và cổng cần kiểm tra
URL="http://localhost:9082/metrics"

# Thư mục lưu trữ số lượng attestations trước đó cho mỗi pubkey
PREV_DIR="/tmp/attestations"
mkdir -p "$PREV_DIR"

# Lấy tất cả các pubkey và số lượng attestations hiện tại
curl -s $URL | grep -E "validator_successful_attestations" | grep 'pubkey=' | while read -r line; do
    # Trích xuất pubkey và giá trị hiện tại
    PUBKEY=$(echo "$line" | grep -oP 'pubkey="\K[^"]+')
    CURRENT_ATTESTATIONS=$(echo "$line" | awk '{print $2}')

    # Đặt tên file lưu số lượng attestations trước đó cho pubkey này
    PREV_FILE="$PREV_DIR/$PUBKEY.txt"

    # Kiểm tra nếu file lưu trữ chưa tồn tại, tạo file và ghi số lượng hiện tại vào
    if [ ! -f "$PREV_FILE" ]; then
        echo "$CURRENT_ATTESTATIONS" > "$PREV_FILE"
        echo "First run for pubkey $PUBKEY. Saving current attestations: $CURRENT_ATTESTATIONS"
        continue
    fi

    # Đọc số lượng attestations trước đó từ file
    PREV_ATTESTATIONS=$(cat "$PREV_FILE")

    # Tính toán sự thay đổi của attestations
    DIFF=$((CURRENT_ATTESTATIONS - PREV_ATTESTATIONS))

    # Cập nhật file với số lượng attestations hiện tại
    echo "$CURRENT_ATTESTATIONS" > "$PREV_FILE"

    # Kiểm tra nếu sự thay đổi đạt hoặc vượt 7 đơn vị
    if [ "$DIFF" -ge 7 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Pubkey $PUBKEY: Attestations increased by $DIFF (>= 7) - OK"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Pubkey $PUBKEY: Attestations increased by $DIFF (< 7) - NOT OK"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Restarting dill service due to low attestations."
        
        # Khởi động lại dịch vụ dill
        systemctl restart dill
    fi
done
