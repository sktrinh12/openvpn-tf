#!/bin/bash

HOME_DIR=/home/ubuntu
# Read the public IP address from the file
PUBLIC_IP=$(cat $HOME_DIR/ip_addr)
OVPN_FILE=client.ovpn

# Check if the PUBLIC_IP variable is set
if [ -z "$PUBLIC_IP" ]; then
  echo "Error: PUBLIC_IP is not set."
  exit 1
fi

# ASCII IP address 
echo "***************************************"
echo "*                                     *"
echo "*          PUBLIC IP ADDRESS          *"
echo "*                                     *"
echo "***************************************"
echo "* $PUBLIC_IP *"
echo "***************************************"

# Update and install OpenVPN and other required packages
sudo apt-get update
sudo apt-get install -y openvpn easy-rsa net-tools
# Copy the server configuration file
cd /usr/share/doc/openvpn/examples/sample-config-files/
sudo cp server.conf /etc/openvpn/server.conf
cd /etc/openvpn/

# Modify server.conf
sudo sed -i 's/;push "redirect-gateway def1 bypass-dhcp"/push "redirect-gateway def1 bypass-dhcp"/' server.conf
sudo sed -i 's/;push "dhcp-option DNS 208.67.222.222"/push "dhcp-option DNS 8.8.8.8"/' server.conf
sudo sed -i 's|ca ca.crt|ca server/ca.crt|' server.conf
sudo sed -i 's|cert server.crt|cert server/server.crt|' server.conf
sudo sed -i 's|key server.key|key server/server.key|' server.conf
sudo sed -i 's|dh dh2048.pem|dh server/dh.pem|' server.conf
sudo sed -i 's/;user nobody/user openvpn/' server.conf
sudo sed -i 's/;group nogroup/group openvpn/' server.conf

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1

# Get the primary network interface
INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')

if [ -z "$INTERFACE" ]; then
  echo "No network interface found. Exiting."
  exit 1
fi

echo "Using network interface: $INTERFACE"


# Configure UFW NAT rules
sudo ufw allow ssh
sudo ufw allow 1194/udp
sudo ufw allow 8080/tcp

sudo sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
sudo sed -i "/# Rules that should be run before the ufw command line added rules\. Custom/a *nat\n:POSTROUTING ACCEPT [0:0]\n-A POSTROUTING -s 10.8.0.0/8 -o $INTERFACE -j MASQUERADE\nCOMMIT" /etc/ufw/before.rules

# Disable and enable UFW with confirmation suppressed
sudo ufw disable
echo "y" | sudo ufw enable

# Easy-RSA setup
sudo cp -r /usr/share/easy-rsa /etc/openvpn
cd /etc/openvpn/easy-rsa
sudo cp vars.example vars

# Update the vars file for certificates
sudo sed -i 's/#set_var EASYRSA_REQ_COUNTRY.*/set_var EASYRSA_REQ_COUNTRY    "US"/' vars
sudo sed -i 's/#set_var EASYRSA_REQ_PROVINCE.*/set_var EASYRSA_REQ_PROVINCE    "Florida"/' vars
sudo sed -i 's/#set_var EASYRSA_REQ_CITY.*/set_var EASYRSA_REQ_CITY        "Miami"/' vars
sudo sed -i 's/#set_var EASYRSA_REQ_ORG.*/set_var EASYRSA_REQ_ORG         "LatAz Certificate Co"/' vars
sudo sed -i 's/#set_var EASYRSA_REQ_EMAIL.*/set_var EASYRSA_REQ_EMAIL       "lataz@proton.me"/' vars
sudo sed -i 's/#set_var EASYRSA_REQ_OU.*/set_var EASYRSA_REQ_OU          "LatAz Org Unit"/' vars

# Easy-RSA operations to build certificates
sudo ./easyrsa clean-all
echo "yes" | sudo ./easyrsa init-pki
echo "server" | sudo ./easyrsa build-ca nopass
echo "server" | sudo ./easyrsa gen-req server nopass
echo "yes" | sudo ./easyrsa sign-req server server
echo "client" | sudo ./easyrsa gen-req client nopass
echo "yes" | sudo ./easyrsa sign-req client client
sudo openssl verify -CAfile pki/ca.crt pki/issued/server.crt
sudo openssl verify -CAfile pki/ca.crt pki/issued/client.crt
sudo ./easyrsa gen-dh

# Generate the TLS key for additional security
cd /etc/openvpn
sudo openvpn --genkey secret ta.key

# Create OpenVPN client configuration file
cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf $HOME_DIR/template.ovpn

# Replace the server IP in client configuration
cd $HOME_DIR
sed -i "s/my-server-1/${PUBLIC_IP}/" template.ovpn
sed -i "s/;ca ca.crt/ca ca.crt/" template.ovpn
sed -i "s/;cert client.crt/cert client.crt/" template.ovpn
sed -i "s/;key client.key/key client.key/" template.ovpn

# Copy the client configuration and certificates
mkdir $HOME_DIR/client
cd /etc/openvpn/easy-rsa
sudo cp pki/ca.crt pki/issued/client.crt pki/private/client.key $HOME_DIR/client/
sudo cp /etc/openvpn/ta.key $HOME_DIR/client/
sudo cp pki/ca.crt /etc/openvpn/server/.
sudo cp pki/issued/server.crt /etc/openvpn/server/.
sudo cp pki/private/server.key /etc/openvpn/server/.
sudo cp pki/dh.pem /etc/openvpn/server/.

# Append certificates and keys to the client.ovpn configuration file
cd $HOME_DIR/client
cp $HOME_DIR/template.ovpn $OVPN_FILE 
echo "<ca>" >> $OVPN_FILE
sudo cat ca.crt >> $OVPN_FILE
echo "</ca>" >> $OVPN_FILE
echo "<cert>" >> $OVPN_FILE
sudo cat client.crt >> $OVPN_FILE
echo "</cert>" >> $OVPN_FILE
echo "<key>" >> $OVPN_FILE
sudo cat client.key >> $OVPN_FILE
echo "</key>" >> $OVPN_FILE
echo "key-direction 1" >> $OVPN_FILE
echo "<tls-auth>" >> $OVPN_FILE
sudo cat ta.key >> $OVPN_FILE
echo "</tls-auth>" >> $OVPN_FILE

# Start and enable OpenVPN server
sudo systemctl enable openvpn@server
sudo systemctl start openvpn@server

# check logs
journalctl -xeu openvpn@server.service | tail -n 50
