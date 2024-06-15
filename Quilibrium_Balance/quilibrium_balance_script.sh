#!/bin/bash

# Define variables
USER_HOME=$(eval echo ~$USER)
NODE_BALANCE_DIR="$USER_HOME/node_balance"
SCRIPT_NAME="balance_by_cunnaredu.py"
SERVICE_NAME="balance_script.service"
PYTHON_SCRIPT_PATH="$NODE_BALANCE_DIR/$SCRIPT_NAME"
LOG_PATH="$NODE_BALANCE_DIR/balance_script.log"
ERROR_LOG_PATH="$NODE_BALANCE_DIR/balance_script_error.log"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"
GET_BALANCE_SCRIPT_PATH="$NODE_BALANCE_DIR/get_balance.sh"

# Create the node_balance directory
mkdir -p $NODE_BALANCE_DIR

# Create the Python script
cat << 'EOF' > $PYTHON_SCRIPT_PATH
import subprocess
import time
import os
from datetime import datetime

# Function to get the unclaimed balance
def get_unclaimed_balance():
    # Run the command
    node_command = ['./node-1.4.19.1-linux-amd64', '-node-info']
    node_directory = os.path.expanduser('~/ceremonyclient/node')
    result = subprocess.run(node_command, cwd=node_directory, stdout=subprocess.PIPE)
    output = result.stdout.decode('utf-8')
    
    # Extract the unclaimed balance from the output
    for line in output.split('\n'):
        if 'Unclaimed balance' in line:
            balance = float(line.split()[2])
            return balance

# Function to calculate average balance increase
def calculate_average(deltas, period):
    if not deltas:
        return 0
    total_delta = sum(deltas)
    average_delta = total_delta / period
    return average_delta

# Initialize variables
balances = []
timestamps = []
balance_deltas = []
sample_interval = 10  # 10 seconds in seconds
output_file = "balance_log.txt"

# Main loop to collect data
try:
    with open(output_file, "a") as file:
        counter = 0
        while True:
            balance = get_unclaimed_balance()
            current_time = datetime.now()
            
            if balances:
                previous_balance = balances[-1]
                balance_delta = balance - previous_balance
                balance_deltas.append(balance_delta)
            
            balances.append(balance)
            timestamps.append(current_time)
            
            # Write current balance and timestamp to the file
            file.write(f"{current_time}: {balance} QUIL\n")
            
            # Calculate and write averages every 10 seconds
            if counter % 90 == 0:  # Check minute average every 15 minutes (15 * 6 * 10s intervals)
                if len(balance_deltas) >= 6:  # 1 minute of 10-second intervals
                    average_per_minute = calculate_average(balance_deltas[-6:], 6)
                    file.write(f"Average unclaimed balance increase per minute: {average_per_minute * 6:.12f} QUIL\n")
                    file.flush()  # Ensure it's written immediately
            
            if counter % 360 == 0:  # Check hourly and daily averages every hour (360 * 10s intervals)
                if len(balance_deltas) >= 360:  # 1 hour of 10-second intervals
                    average_per_hour = calculate_average(balance_deltas[-360:], 360)
                    file.write(f"Average unclaimed balance increase per hour: {average_per_hour * 360:.12f} QUIL\n")
                    file.flush()  # Ensure it's written immediately
            
                if len(balance_deltas) >= 8640:  # 24 hours of 10-second intervals
                    average_per_day = calculate_average(balance_deltas[-8640:], 8640)
                    file.write(f"Average unclaimed balance increase per day: {average_per_day * 8640:.12f} QUIL\n")
                    file.flush()  # Ensure it's written immediately
            
            # Flush the file buffer to ensure data is written to the file
            file.flush()
            
            # Wait for the next sample interval
            time.sleep(sample_interval)
            counter += 1
except KeyboardInterrupt:
    with open(output_file, "a") as file:
        file.write("Script terminated by user.\n")
EOF

# Make the Python script executable
chmod +x $PYTHON_SCRIPT_PATH

# Create the systemd service file
sudo bash -c "cat << EOF > $SERVICE_PATH
[Unit]
Description=Balance Script Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 $PYTHON_SCRIPT_PATH
WorkingDirectory=$NODE_BALANCE_DIR
StandardOutput=file:$LOG_PATH
StandardError=file:$ERROR_LOG_PATH
Restart=always
User=$USER

[Install]
WantedBy=multi-user.target
EOF"

# Create the get_balance.sh script
cat << 'EOF' > $GET_BALANCE_SCRIPT_PATH
#!/bin/bash

# Define variables
USER_HOME=$(eval echo ~$USER)
LOG_FILE="$USER_HOME/node_balance/balance_log.txt"

# Function to extract the latest value for a specific metric
extract_latest_value() {
    local metric=$1
    grep "$metric" $LOG_FILE | tail -n 1 | awk '{print $(NF-1)}'
}

# Extract the current unclaimed balance
current_balance=$(grep "QUIL" $LOG_FILE | tail -n 1 | awk '{print $(NF-1)}')

# Extract the average increases
minute_average=$(extract_latest_value "Average unclaimed balance increase per minute")
hour_average=$(extract_latest_value "Average unclaimed balance increase per hour")
day_average=$(extract_latest_value "Average unclaimed balance increase per day")

# Handle missing values
current_balance=${current_balance:-"no data yet"}
minute_average=${minute_average:-"no data yet"}
hour_average=${hour_average:-"no data yet"}
day_average=${day_average:-"no data yet"}

# Print results
echo "Current unclaimed balance: ${current_balance} QUIL"
echo "Average unclaimed balance increase per minute: ${minute_average} QUIL"
echo "Average unclaimed balance increase per hour: ${hour_average} QUIL"
echo "Average unclaimed balance increase per day: ${day_average} QUIL"
EOF

# Make the get_balance.sh script executable
chmod +x $GET_BALANCE_SCRIPT_PATH

# Reload systemd, enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME

echo "Service $SERVICE_NAME has been set up and started."
echo "Your balance and logs are located at $GET_BALANCE_SCRIPT_PATH."
echo "To get your current and average QUIL(minute,hour,and daily), use the following command:"
echo "cd ~/node_balance && ./get_balance.sh"
