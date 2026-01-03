#!/usr/bin/env bash
# Script to check if Nomad scheduler algorithm is set to spread

echo "=== Checking Nomad Scheduler Configuration ==="
echo ""

# Check systemd service status
echo "1. Systemd service status:"
ssh s01 "systemctl status configure-nomad-scheduler --no-pager -l" || echo "Service status check failed"
echo ""

# Check current scheduler algorithm via API
echo "2. Current scheduler algorithm (via API):"
ssh s01 "curl -s http://127.0.0.1:4646/v1/operator/scheduler/configuration | jq -r '.SchedulerAlgorithm // \"not set\"'" || echo "API check failed"
echo ""

# Show full scheduler configuration
echo "3. Full scheduler configuration:"
ssh s01 "curl -s http://127.0.0.1:4646/v1/operator/scheduler/configuration | jq ." || echo "API check failed"
echo ""

# Alternative: using nomad CLI if available
echo "4. Using Nomad CLI (if available):"
ssh s01 "nomad operator scheduler config 2>/dev/null | grep -i 'scheduler.*algorithm\|algorithm.*scheduler' || echo 'Nomad CLI not available or different output format'"
echo ""

echo "=== Done ==="

