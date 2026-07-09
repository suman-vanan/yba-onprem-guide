#!/bin/bash

# ==========================================
# Network Connectivity Checker
# ==========================================

# ANSI Colors for Output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if netcat is installed
if ! command -v nc &> /dev/null; then
    echo "Error: 'netcat' is not installed."
    echo "Please run: sudo dnf install nc -y"
    exit 1
fi

# Verify Arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <host1,host2,...> <port1,port2,...>"
    echo "Example: $0 192.168.1.10,db-node-02 3306,4444,4567"
    exit 1
fi

HOSTS_INPUT=$1
PORTS_INPUT=$2

# Convert comma-separated strings to arrays
IFS=',' read -r -a HOST_LIST <<< "$HOSTS_INPUT"
IFS=',' read -r -a PORT_LIST <<< "$PORTS_INPUT"

echo "------------------------------------------------"
echo "Starting Connectivity Check..."
echo "Target Hosts: ${#HOST_LIST[@]}"
echo "Target Ports: ${#PORT_LIST[@]}"
echo "------------------------------------------------"

# Loop through Hosts and Ports
echo "------------------------------------------------"
echo "Checking Network Paths (Service status ignored)"
echo "------------------------------------------------"

for HOST in "${HOST_LIST[@]}"; do
    HOST=$(echo "$HOST" | xargs)
    echo "Target: $HOST"
    
    for PORT in "${PORT_LIST[@]}"; do
        PORT=$(echo "$PORT" | xargs)

        # Capture both Standard Output and Error to a variable
        # -v is required here to get the error text
        OUTPUT=$(nc -zv -w 2 "$HOST" "$PORT" 2>&1)
        RESULT=$?

        # Check the result text to distinguish the cause
        if [ $RESULT -eq 0 ]; then
            # The port is actually open and a service is running
            echo -e "  [ ${GREEN}OPEN${NC} ] Port $PORT (Service is running)"
            
        elif [[ "$OUTPUT" == *"refused"* ]]; then
            # The packet arrived, but nothing is listening. 
            # This confirms the FIREWALL IS OPEN.
            echo -e "  [ ${YELLOW}VERIFIED${NC} ] Port $PORT (Network Open, No Service)"
            
        else
            # Timeout or No Route - The firewall/network is blocking it.
            echo -e "  [ ${RED}BLOCKED${NC} ] Port $PORT (Timeout / Firewall Drop)"
        fi
    done
    echo "------------------------------------------------"
done