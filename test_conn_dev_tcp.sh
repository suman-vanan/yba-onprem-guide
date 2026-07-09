#!/bin/bash

# ==============================================================================
# Usage Example: 
#   ./test_conn.sh "192.168.1.10 192.168.1.11" "22 80 443 3306"
#
# Note: Be sure to enclose the lists in quotes so they are passed as 
# single strings to the script.
# ==============================================================================

# Check if exactly two arguments are passed; if not, print usage and exit
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 \"<space-separated hosts>\" \"<space-separated ports>\""
  echo "Example: $0 \"192.168.1.10 10.0.0.5\" \"22 80 443\""
  exit 1
fi

# Convert the quoted strings from the command line into Bash arrays
HOSTS=($1)
PORTS=($2)

echo "Starting connectivity test..."
echo "---------------------------"

for host in "${HOSTS[@]}"; do
  for port in "${PORTS[@]}"; do
    
    # Run the connection test and capture the exit code
    timeout 2 bash -c "</dev/tcp/$host/$port" &>/dev/null
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
      echo "[OPEN]    $host:$port - Connected successfully."
    elif [ $EXIT_CODE -eq 124 ]; then
      echo "[BLOCKED] $host:$port - Connection timed out (Firewall block or host down)."
    else
      echo "[REFUSED] $host:$port - Network reachable, but no service listening."
    fi
    
  done
done