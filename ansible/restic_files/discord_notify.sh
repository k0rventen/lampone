#!/bin/bash

WEBHOOK_URL="{{discord_webhook}}"
SYSTEMD_UNIT=$1

unit_status=$(systemctl status --full --no-pager --lines=0 ${SYSTEMD_UNIT} | jq -Rsa .)
unit_logs=$(journalctl -n 5 --full --no-pager -o cat -u ${SYSTEMD_UNIT} | jq -Rsa .)

curl -H "Content-Type: application/json" -d "{\"content\":\"## $SYSTEMD_UNIT systemctl report\" ,\"embeds\":[{\"title\":\"$SYSTEMD_UNIT status\",\"description\":$unit_status},{\"title\":\"$SYSTEMD_UNIT logs\",\"description\":$unit_logs}] }" "$WEBHOOK_URL"
