# Setting Up OpenVPN on Ubuntu

This guide provides a step-by-step process for installing and configuring OpenVPN on an Ubuntu server. It includes commands for installation, configuration, and setup for both server and client.

## Prerequisites

- Ubuntu server
- Root or sudo privileges

## Installation

1. **Update Package List**

   ```bash
   sudo apt-get update
   ```

2. **Install OpenVPN and Easy-RSA**

   ```bash
   sudo apt-get install -y openvpn easy-rsa net-tools
   ```

## Server Configuration

1. **Copy Sample Configuration**

   ```bash
   cd /usr/share/doc/openvpn/examples/sample-config-files/
   sudo cp server.conf /etc/openvpn/server.conf
   ```

2. **Edit Configuration File**

   ```bash
   cd /etc/openvpn/
   sudo vi server.conf
   ```

   Update the following lines in `server.conf`:

   ```plaintext
   ca server/ca.crt
   cert server/server.crt
   key server/server.key  # This file should be kept secret
   dh server/dh.pem

   push "redirect-gateway def1 bypass-dhcp"

   push "dhcp-option DNS 8.8.8.8"
   ;push "dhcp-option DNS 208.67.220.220"

   user openvpn
   group openvpn
   ```

3. **Enable IP Forwarding**

   ```bash
   sudo sysctl -w net.ipv4.ip_forward=1
   ```

4. **Configure UFW**

   Allow OpenVPN and SSH through the firewall:

   ```bash
   sudo ufw allow ssh
   sudo ufw allow 1194/udp
   ```

   Edit `/etc/default/ufw` and `/etc/ufw/before.rules` to set up NAT for the VPN:

   ```bash
   sudo vi /etc/ufw/before.rules
   ```

   Add the following lines:

   ```plaintext
   *nat
   :POSTROUTING ACCEPT [0:0]
   -A POSTROUTING -s 10.8.0.0/8 -o enX0 -j MASQUERADE
   COMMIT
   ```

   Restart UFW:

   ```bash
   sudo ufw disable
   sudo ufw enable
   ```

## Generate Certificates and Keys

1. **Prepare Easy-RSA**

   ```bash
   sudo cp -r /usr/share/easy-rsa /etc/openvpn
   sudo cp /etc/openvpn/easy-rsa/vars.example /etc/openvpn/easy-rsa/vars
   sudo vi /etc/openvpn/easy-rsa/vars
   ```

   Edit the variables (Country, Province, City, Org, Email, and OU) as needed.

2. **Generate Certificates and Keys**

   ```bash
   cd /etc/openvpn/easy-rsa
   sudo ./easyrsa clean-all
   sudo ./easyrsa init-pki
   sudo ./easyrsa build-ca server nopass
   sudo ./easyrsa gen-req server nopass
   sudo ./easyrsa sign-req server server
   sudo ./easyrsa gen-req client nopass
   sudo ./easyrsa sign-req client client
   sudo openssl verify -CAfile pki/ca.crt pki/issued/server.crt
   sudo openssl verify -CAfile pki/ca.crt pki/issued/client.crt
   sudo ./easyrsa gen-dh
   ```

3. **Move Certificates and Keys**

   ```bash
   sudo cp pki/ca.crt /etc/openvpn/server/.
   sudo cp pki/issued/server.crt /etc/openvpn/server/.
   sudo cp pki/private/server.key /etc/openvpn/server/.
   sudo cp pki/dh.pem /etc/openvpn/server/.
   
   # For client
   sudo cp pki/ca.crt /etc/openvpn/client/.
   sudo cp pki/issued/client.crt /etc/openvpn/client/.
   sudo cp pki/private/client.key /etc/openvpn/client/.
   ```

4. **Generate TLS Key**

   ```bash
   cd /etc/openvpn
   sudo openvpn --genkey secret ta.key
   ```

## Start OpenVPN Server

1. **Start and Check Status**

   ```bash
   sudo systemctl start openvpn@server
   sudo systemctl status openvpn@server
   ```

2. **Monitor Logs**

   ```bash
   sudo watch tail /var/log/openvpn/openvpn.log
   ```

## Client Configuration

1. **Create Client Configuration File**

   Copy and edit the client configuration template:

   ```bash
   cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf ~/template.ovpn
   cd ~
   vi template.ovpn
   ```

   **Edit the `remote` directive** in the `template.ovpn` file to point to the public IP address of your OpenVPN server:

   ```plaintext
   remote 34.193.47.15 1194
   ```

   **Uncomment the user and group directives** to run the OpenVPN client with downgraded privileges:

   ```plaintext
   user nobody
   group nogroup
   ```

   **Remove or comment out the `ca`, `cert`, and `key` directives** if they are included:

   ```plaintext
   ;ca ca.crt
   ;cert client.crt
   ;key client.key
   ```

2. **Prepare Client Files**

   Create a directory for client configuration and move necessary files:

   ```bash
   mkdir ~/client
   cd /etc/openvpn/client
   sudo cp ca.crt client.crt client.key ~/client
   cd ~/client
   sudo cp /etc/openvpn/ta.key ~/client
   cp ~/template.ovpn ~/client/client.ovpn
   ls
   ```

3. **Append Certificates and Keys to Client Configuration**

   Append the contents of the certificates and keys to `client.ovpn`:

   ```bash
   # For the CA certificate
   echo "<ca>" >> client.ovpn
   sudo cat ca.crt >> client.ovpn
   echo "</ca>" >> client.ovpn

   # For the client certificate
   echo "<cert>" >> client.ovpn
   sudo cat client.crt >> client.ovpn
   echo "</cert>" >> client.ovpn

   # For the client key
   echo "<key>" >> client.ovpn
   sudo cat client.key >> client.ovpn
   echo "</key>" >> client.ovpn

   # For the TLS key and direction
   echo "key-direction 1" >> client.ovpn
   echo "<tls-auth>" >> client.ovpn
   sudo cat ta.key >> client.ovpn
   echo "</tls-auth>" >> client.ovpn
   ```

4. **Check OpenVPN Server Logs**

   Verify that the OpenVPN server is running correctly and check its logs:

   ```bash
   sudo journalctl -u openvpn@server
   ```

## Client-Side Testing

1. **Create OpenVPN User and Group**

   On the client side, create a new group and user for OpenVPN:

   ```bash
   sudo groupadd openvpn
   sudo useradd openvpn -g openvpn
   ```

2. **Test OpenVPN with Docker**

   Use a Docker container to test the OpenVPN client configuration. Run the following command from within the client directory, which contains all the certificates, keys, and the `.ovpn` file:

   ```bash
   sudo docker run \
     --name openvpn \
     --privileged \
     -v "$(pwd)":/etc/openvpn \
     -p 1194:1194/udp \
     --cap-add=NET_ADMIN \
     kylemanna/openvpn \
     /bin/sh -c "openvpn --config /etc/openvpn/client.ovpn"
   ```

   This command will start a Docker container with OpenVPN pre-installed and configured to use the provided `.ovpn` file.

## Conclusion

You have now set up OpenVPN on your Ubuntu server and configured a client. The server should be running and accepting connections, and the client configuration is ready for testing. Make sure to monitor both server and client logs for any issues and validate the connection. For more details and troubleshooting, consult the [OpenVPN documentation](https://openvpn.net/community-resources/).
