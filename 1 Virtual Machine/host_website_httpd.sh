#!/bin/bash

# -----------------------------------------------------------------------
# Capture Script Execution Logs
# -----------------------------------------------------------------------

# Create Log file to store execution logs
LOG_FILE="/var/log/custom-data-script.log"

# Redirect stdout and stderr to the log file
exec >> "$LOG_FILE" 2>&1

# Log the start time
echo "Script started at $(date)"

# -----------------------------------------------------------------------
# Deploy Pre-Requisites - Installing all required packages
# -----------------------------------------------------------------------

# 1 Install FirewallD
sudo yum install -y firewalld

# 2 Install MariaDB
sudo yum install -y mariadb-server
sudo service mariadb start
sudo systemctl enable mariadb

# 3 Install required packages for httpd and PHP
sudo yum install -y httpd php php-mysqlnd

# 4 Install Git
sudo yum install -y git

# -----------------------------------------------------------------------
# Configure FirewallD for MySQL (Port 3306) and HTTP (Port 80)
# Add MySQL (Port 3306) and HTTP (Port 80) to the public.xml file
# -----------------------------------------------------------------------

# Create a temporary XML file with the required lines
temp_xml=$(mktemp)
echo '<?xml version="1.0" encoding="utf-8"?>
<zone>
  <service name="dhcpv6-client"/>
  <service name="dns"/>
  <port protocol="tcp" port="3306"/>
  <port protocol="tcp" port="80"/>
</zone>' >"$temp_xml"

# Merge the temporary XML with the existing public.xml file
sudo cp /etc/firewalld/zones/public.xml /etc/firewalld/zones/public.xml.bak
sudo xmllint --format "$temp_xml" | sudo tee /etc/firewalld/zones/public.xml >/dev/null

# -----------------------------------------------------------------------
# Deploy and Configure Database
# -----------------------------------------------------------------------

# SQL statements

SQL1="CREATE DATABASE IF NOT EXISTS ecomdb;"
SQL2="CREATE USER 'ecomuser'@'localhost' IDENTIFIED BY 'ecompassword';"
SQL3="GRANT ALL PRIVILEGES ON *.* TO 'ecomuser'@'localhost';"
SQL4="FLUSH PRIVILEGES;"

# Execute SQL statements

sudo mysql -e "$SQL1"
sudo mysql -e "$SQL2"
sudo mysql -e "$SQL3"
sudo mysql -e "$SQL4"

echo "Database setup completed."

# Load Product Inventory Information to database

cat > db-load-script.sql <<-EOF
USE ecomdb;
CREATE TABLE products (id mediumint(8) unsigned NOT NULL auto_increment,Name varchar(255) default NULL,Price varchar(255) default NULL, ImageUrl varchar(255) default NULL,PRIMARY KEY (id)) AUTO_INCREMENT=1;

INSERT INTO products (Name,Price,ImageUrl) VALUES ("Laptop","100","c-1.png"),("Drone","200","c-2.png"),("VR","300","c-3.png"),("Tablet","50","c-5.png"),("Watch","90","c-6.png"),("Phone Covers","20","c-7.png"),("Phone","80","c-8.png"),("Laptop","150","c-4.png");

EOF

# Run sql script

sudo mysql < db-load-script.sql

# -----------------------------------------------------------------------
# Deploy and Configure Web
# -----------------------------------------------------------------------

# Change DirectoryIndex index.html to DirectoryIndex index.php to make the php page the default page

sudo sed -i 's/index.html/index.php/g' /etc/httpd/conf/httpd.conf

# Download code

sudo yum install -y git
sudo rm -r /var/www/html
sudo git clone https://github.com/kodekloudhub/learning-app-ecommerce.git /var/www/html/

# Update index.php

sudo sed -i 's/172.20.1.101/localhost/g' /var/www/html/index.php

# -----------------------------------------------------------------------
# Retarting httpd and firewalld to reload newly added firewall rules
# -----------------------------------------------------------------------

sudo service httpd restart
sudo service firewalld restart
sudo systemctl enable firewalld

# Log the end time
echo "Script finished at $(date)"
