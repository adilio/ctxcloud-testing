#!/bin/bash
# Set the system hostname to match the scenario name
sudo hostnamectl set-hostname "${OWNER}-${SCENARIO_NAME}"

# Disable automatic updates
sudo systemctl stop apt-daily.timer
sudo systemctl stop apt-daily-upgrade.timer
sudo systemctl disable apt-daily.timer
sudo systemctl disable apt-daily-upgrade.timer

# Install outdated packages
sudo apt-get update
sudo apt-get install -y nginx=1.18.* php7.4 mysql-client-5.7

# Create vulnerable web directory
sudo mkdir -p /var/www/html
echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/info.php > /dev/null

# Place fake API key as canary
echo "${DUMMY_API_KEY}" | sudo tee /var/www/html/api_key.txt > /dev/null
# Also expose fake high-risk keys for CSPM scanner detection
echo "${STRIPE_KEY}" | sudo tee /var/www/html/stripe_key.txt > /dev/null
echo "${AWS_KEY}" | sudo tee /var/www/html/aws_key.txt > /dev/null
echo "${GITHUB_TOKEN}" | sudo tee /var/www/html/github_token.txt > /dev/null

# Enable nginx directory listing
sudo sed -i '/location \/ {/a autoindex on;' /etc/nginx/sites-available/default
sudo systemctl restart nginx
