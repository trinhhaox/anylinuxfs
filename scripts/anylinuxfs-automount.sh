#!/bin/zsh
# ==============================================================================
# anylinuxfs Auto-Mount Watcher Daemon for macOS
# Tự động phát hiện khi cắm ổ đĩa ngoài NTFS/Linux, unmount bản Read-Only của macOS
# và tự động kích hoạt anylinuxfs mount ở chế độ Full Read-Write.
# ==============================================================================

INTERVAL=3
LOG_FILE="$HOME/Library/Logs/anylinuxfs-automount.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] anylinuxfs Auto-Mount Daemon started" >> "$LOG_FILE"

while true; do
    # Tìm kiếm các phân vùng NTFS được macOS mount read-only
    # Cấu trúc: mount output có dạng "/dev/diskXsY on /Volumes/... (..., read-only, ...)"
    while read -r line; do
        DEV=$(echo "$line" | awk '{print $1}')
        MNT_POINT=$(echo "$line" | awk -F' on ' '{print $2}' | awk -F' \\(' '{print $1}')
        OPTS=$(echo "$line" | awk -F'\\(' '{print $2}' | tr -d ')')

        # Kiểm tra xem có phải mountpoint thuộc /Volumes và có read-only không
        if [[ "$MNT_POINT" == /Volumes/* && "$OPTS" == *"read-only"* ]]; then
            # Kiểm tra loại filesystem qua diskutil
            FS_TYPE=$(diskutil info "$DEV" 2>/dev/null | grep "Type (Bundle):" | awk '{print $3}')
            
            if [[ "$FS_TYPE" == "ntfs" ]]; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Phát hiện phân vùng NTFS Read-Only: $DEV tại $MNT_POINT" >> "$LOG_FILE"
                
                # Unmount phân vùng read-only của macOS
                diskutil unmount "$DEV" >> "$LOG_FILE" 2>&1
                
                if [ $? -eq 0 ]; then
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Đang kích hoạt anylinuxfs mount cho $DEV..." >> "$LOG_FILE"
                    # Gọi anylinuxfs mount (chạy nền)
                    /opt/homebrew/bin/anylinuxfs mount "$DEV" >> "$LOG_FILE" 2>&1 &
                fi
            fi
        fi
    done < <(mount | grep -iE 'ntfs|read-only')

    sleep "$INTERVAL"
done
