#!/usr/bin/env bash
# Script to manually set Nomad scheduler algorithm to spread

echo "Setting Nomad scheduler algorithm to spread..."

# Set the scheduler algorithm via API
curl -X POST http://127.0.0.1:4646/v1/operator/scheduler/configuration \
	-H "Content-Type: application/json" \
	-d '{
		"SchedulerAlgorithm": "spread"
	}'

echo ""
echo "Verifying configuration..."
nomad operator scheduler get-config | grep "Scheduler Algorithm"

