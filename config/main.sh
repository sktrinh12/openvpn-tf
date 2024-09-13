#!/bin/bash

# Check if an argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 [up|down]"
    exit 1
fi

echo '.....................'
echo "argument passed: $1"
echo '.....................'

# Set the path to the Terraform project directory
TF_DIR=$HOME/Documents/scripts/terraform/openvpn-ec2
PRIVATE_KEY=openvpn_key.pem
LOCAL_OVPN_PATH="$HOME/Downloads/client.ovpn"

cd $TF_DIR

case "$1" in
  up)
    # Commands to deploy VPN server
    echo "Deploying VPN server..."

    # Run Terraform to deploy the VPN server
    terraform apply -auto-approve

    # Get the server IP address from Terraform output
    SERVER_IP=$(terraform output -raw instance_ip)

    # Wait for the server to be available on port 22 (SSH)
    echo "Waiting for the server ($SERVER_IP) to be available on SSH..."
    while ! nc -z $SERVER_IP 22; do
      sleep 6
    done

    # Download the .ovpn file using scp
    echo "Downloading the .ovpn file from the server..."
    scp -o StrictHostKeyChecking=no -i $PRIVATE_KEY ubuntu@$SERVER_IP:/home/ubuntu/client/client.ovpn $LOCAL_OVPN_PATH

    # Notify completion
    if [ $? -eq 0 ]; then
        echo "VPN setup complete. The client.ovpn file is saved at $LOCAL_OVPN_PATH"
    else
        echo "Failed to download the client.ovpn file."
    fi
    ;;
  down)
    # Commands to tear down VPN server
    echo "Tearing down VPN server..."
    # Run Terraform to destroy the VPN server
    terraform destroy -auto-approve

    rm $LOCAL_OVPN_PATH

    echo "Shutdown complete, and the local files have been removed."
    ;;
  *)
    echo "Invalid argument. Use 'up' or 'down'."
    exit 1
    ;;
esac
