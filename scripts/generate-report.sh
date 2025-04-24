#!/bin/bash

echo "📝 Generating Monitoring System Report..."

REPORT_PATH="./monitoring_status_report.md"

if [ -f "$REPORT_PATH" ]; then
  echo "✅ Found report at $REPORT_PATH"
  echo "----------------------------------"
  cat "$REPORT_PATH"
  echo "----------------------------------"
else
  echo "❌ Report not found. Run automation first:"
  echo "   ./scripts/run_monitoring_automation.sh"
fi
