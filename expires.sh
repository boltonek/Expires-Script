#!/bin/bash
# Epires Script v. 2.0
# Blocks user accounts that have passed their expiry date
# Version: v. 2.0
#
# Format of /etc/expires:
#   username DD/MM/YY
#   username2 DD/MM/YY

set -uo pipefail

# ============================================================
# CONFIGURATION
# ============================================================
LOG="/var/log/userexpire"
ACCOUNTS="/etc/expires"

# ============================================================
# FUNCTIONS
# ============================================================

# Write a timestamped message to the log and stdout
log() {
    local TIMESTAMP
    TIMESTAMP=$(date "+%d/%m/%y %H:%M:%S")
    echo "$TIMESTAMP - $1" | tee -a "$LOG"
}

separator() {
    echo "-----------------------------------------" | tee -a "$LOG"
}

# ============================================================
# ROOT CHECK
# ============================================================
if [ "$(id -u)" != "0" ]; then
    echo "Error: You do not have root privileges!" >&2
    exit 1
fi

# ============================================================
# FILE CHECKS
# ============================================================
if [ ! -f "$LOG" ]; then
    echo "Error: Log file $LOG does not exist. Please create it first!" >&2
    exit 1
fi

if [ ! -f "$ACCOUNTS" ]; then
    echo "Error: Accounts file $ACCOUNTS does not exist!" >&2
    exit 1
fi

# ============================================================
# START
# ============================================================
separator
log "SCRIPT STARTED"
separator

# ============================================================
# MAIN LOOP
# ============================================================
while IFS= read -r i; do
    # Skip empty lines and comments
    [[ -z "$i" || "$i" == \#* ]] && continue

    USERNAME=$(echo "$i" | awk '{print $1}')
    EXPIRY_DATE=$(echo "$i" | awk '{print $2}' | tr -d '/')
    TODAY=$(date "+%d%m%y")

    # Check if the account expiry date has been reached
    if [ "$EXPIRY_DATE" = "$TODAY" ]; then

        # Check if the user actually exists on the system
        if ! getent passwd "$USERNAME" > /dev/null 2>&1; then
            log "Account $USERNAME is marked as expired, but the user does not exist on this system."
            continue
        fi

        log "Account of user $USERNAME expired on $EXPIRY_DATE"

        # Lock the user's login shell
        log "Setting default shell to /bin/false for $USERNAME"
        if ! chsh -s /bin/false "$USERNAME" 2>/dev/null; then
            log "Warning: Failed to change shell for $USERNAME"
        fi

        # Kill all user processes
        log "Killing processes for user $USERNAME..."
        if pkill -9 -u "$USERNAME" 2>/dev/null; then
            log "Processes for user $USERNAME terminated [OK]"
        else
            log "No active processes found for $USERNAME or an error occurred."
        fi
    fi

done < "$ACCOUNTS"

# ============================================================
# END
# ============================================================
separator
log "SCRIPT COMPLETED SUCCESSFULLY"
separator
