#!/bin/bash

# Main Shell Script (No need to modify)

sudo dnf -y install httpd php8.1 php8.1-mbstring php-mysqli

wget https://wordpress.org/latest.tar.gz -P /tmp/
tar zxvf /tmp/latest.tar.gz -C /tmp
sudo cp -r /tmp/wordpress/* /var/www/html/
sudo chown apache:apache -R /var/www/html

sudo systemctl enable httpd.service
sudo systemctl restart httpd.service
