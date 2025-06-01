#!/usr/bin/env bash

# smart-notify: Intelligent notification routing
# Usage: smart-notify <level> <title> <message> [tags]

LEVEL="$1"
TITLE="$2" 
MESSAGE="$3"
TAGS="$4"

CURRENT_HOUR=$(date +%H)
BASE_URL="http://100.64.0.1:8080"  # Use VPN address

# Determine if we're in work hours (9-18)
IS_WORK_HOURS=false
if [ $CURRENT_HOUR -ge 9 ] && [ $CURRENT_HOUR -lt 18 ]; then
  IS_WORK_HOURS=true
fi

case "$LEVEL" in
  "critical")
    # Always push critical alerts
    curl -d "$MESSAGE" \
      -H "Title: 🚨 $TITLE" \
      -H "Priority: 5" \
      -H "Tags: rotating_light,$TAGS" \
      "$BASE_URL/server-critical"
    ;;
  "warning") 
    # Only during work hours
    if [ "$IS_WORK_HOURS" = true ]; then
      curl -d "$MESSAGE" \
        -H "Title: ⚠️ $TITLE" \
        -H "Priority: 4" \
        -H "Tags: warning,$TAGS" \
        "$BASE_URL/server-warning"
    fi
    ;;
  "info")
    # Dashboard only - no push notification
    echo "$(date): [INFO] $TITLE - $MESSAGE" >> /var/log/dashboard-events.log
    ;;
  "summary")
    # Weekly summary topic  
    curl -d "$MESSAGE" \
      -H "Title: 📊 $TITLE" \
      -H "Priority: 2" \
      -H "Tags: chart_with_upwards_trend,$TAGS" \
      "$BASE_URL/server-summary"
    ;;
esac