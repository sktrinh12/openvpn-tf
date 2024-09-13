#!/bin/bash

HOME_DIR="/home/ubuntu"
OVPN_FILE="$HOME_DIR/template.ovpn"

touch "$OVPN_FILE"
PUBLIC_IP=$(cat $HOME_DIR/ip_addr)

if [ -z "$PUBLIC_IP" ]; then
  echo "Error: PUBLIC_IP is not set."
  exit 1
fi

{
  echo "***************************************"
  echo "*                                     *"
  echo "*          PUBLIC IP ADDRESS          *"
  echo "*                                     *"
  echo "***************************************"
  echo "* $PUBLIC_IP *"
  echo "***************************************"
} >> "$OVPN_FILE"

sudo ufw allow 8080/tcp
sudo apt-get install -y apache2

cp "$OVPN_FILE" /var/www/html/

sudo sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf
sudo sed -i 's/<VirtualHost *:80>/<VirtualHost *:8080>/' /etc/apache2/sites-available/000-default.conf

sudo sed -i 's/<VirtualHost \*:80>/<VirtualHost \*:8080>/' /etc/apache2/sites-available/000-default.conf

sudo sed -i '/DocumentRoot \/var\/www\/html/a \
<Directory "/var/www/html">\
\nOptions Indexes FollowSymLinks\
\nAllowOverride None\
\nRequire all granted\
\n</Directory>' /etc/apache2/sites-available/000-default.conf

sudo systemctl start apache2

echo "The .ovpn file has been served at http://$PUBLIC_IP:8080/template.ovpn"

CRON_JOB="0 $(date +'%H') $(date +'%d') $(date +'%m') * sudo systemctl stop apache2"

(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo "A cron job has been set to shut down Apache in one hour."
crontab -l
