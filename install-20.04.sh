#!/bin/bash
#
# Installation Odoo 14 on Ubuntu 20.04
#

PWD=$(pwd) # Get current position
. $PWD/odoo14.conf # put files odoo14.conf and  install-20.04.sh in the same folder

# Create directory for installation
mkdir -p $installation_dir

# Go to installation directory
cd $installation_dir

# Update Server
sudo apt-get update -qq
sudo apt-get -yy upgrade

# Create Odoo User 
sudo adduser -system -home=/opt/odoo -group $odoo_user

# Install Postgresql Server
sudo apt-get install postgresql -yy

# Create Odoo user for PostgreSQL
sudo su - postgres -c "createuser -s $odoo_db_user" 2> /dev/null || true

ls -l /etc/ssl/private/ssl-cert-snakeoil.key
sudo chmod 0640 /etc/ssl/private/ssl-cert-snakeoil.key
sudo service postgresql restart

# Install Python Dependencies
sudo apt-get install -yy git python3 python3-pip build-essential wget \
	python3-dev python3-venv python3-wheel libxslt-dev libzip-dev \
	libldap2-dev libsasl2-dev python3-setuptools node-less libjpeg-dev gdebi \
	libpq-dev python-dev libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev libffi-dev

# Install Python PIP Dependencies
sudo -H pip3 install -r $requirement_url
#khai add
sudo apt-get install python3-pip
sudo apt-get install python3-psycopg2
sudo pip install babel==2.16.0
sudo pip install passlib==1.7.4
sudo pip install decorator==5.1.1
sudo pip install polib==1.2.0
sudo pip install psutil==6.1.0
sudo pip install jinja2==3.1.4

sudo pip install PyPDF2==1.26.0
sudo pip install Werkzeug==2.0.2
sudo pip install lxml==4.6.5
sudo pip install docutils==0.14
sudo pip install libsass==0.17.0

sudo pip install freezegun==1.5.1
sudo pip install xlrd==2.0.1
sudo pip install pyxlsb==1.0.10
# Install other required packages
sudo apt-get install -yy  nodejs npm

# Before install npm packages, initialize file package.json
# to avoid error: npm WARN saveError ENOENT: no such file or directory, open package.json
npm init -y
sudo npm install -g rtlcss
if [ $? -ne 0 ]; then
	echo "Got error... Trying again..."
	npm config set strict-ssl false
	npm install rtlcss
	if [ $? -eq 0 ]; then
		echo "stlcss installed successfully"
	fi
fi

# Install Wkhtmltopdf
sudo apt-get install -yy xfonts-75dpi
sudo wget --no-check-certificate $wkhtmltox_url/$wkhtmltox_deb_file
sudo dpkg -i $wkhtmltox_deb_file
sudo cp /usr/local/bin/wkhtmltoimage /usr/bin/wkhtmltoimage
sudo cp /usr/local/bin/wkhtmltopdf /usr/bin/wkhtmltopdf

# Create Log directory
sudo mkdir $odoo_log_dir
sudo chown $odoo_user:$odoo_user $odoo_log_dir

# Install Odoo
# sudo mkdir -p $odoo_server_location
if [ "$1" = "staging" ]; then #install from staging branch
    echo "sudo git clone $github_staging_url $odoo_server_location"
    sudo git clone -b staging -c http.sslverify=false $github_staging_url $odoo_server_location
elif [ "$1" = "uat" ]; then
    echo "sudo git clone -b uat -c http.sslverify=false  $github_staging_url $odoo_server_location"
    sudo git clone -b uat -c http.sslverify=false  $github_staging_url $odoo_server_location
elif [ "$1" = "prod" ] ; then # insstall from production branch
    echo "sudo git clone -b master -c http.sslverify=false $github_staging_url $odoo_server_location"
    sudo git clone -c http.sslverify=false $github_staging_url $odoo_server_location
else
    echo "sudo git clone --depth 1 -c http.sslverify=false --branch 14.0 $github_default_url $odoo_server_location"
    sudo git clone --depth 1 -c http.sslverify=false --branch 14.0 $github_default_url $odoo_server_location
fi

# Setting permissions on home folder
sudo chown -R $odoo_user:$odoo_user $odoo_server_location

# Create server config file
echo $odoo_config_file
sudo touch $odoo_config_file
sudo cp /dev/null $odoo_config_file
sudo su root -c "printf '[options] \n; This is the password that allows database operations:\n' >> $odoo_config_file"
sudo su root -c "printf 'admin_passwd = admin\n' >> $odoo_config_file"
sudo su root -c "printf 'xmlrpc_port = 8069\n' >> $odoo_config_file"
sudo su root -c "printf 'logfile = $odoo_log_dir/odoo-server.log\n' >> $odoo_config_file"
sudo su root -c "printf 'addons_path=/odoo/odoo-server/addons,/odoo/odoo-server/addons_custom\n' >> $odoo_config_file"
sudo chown $odoo_user:$odoo_user $odoo_config_file
sudo chmod 640 $odoo_config_file

# Setup odoo service
# Creating Systemd Unit File
odoo_service_file_path=/etc/systemd/system/$odoo_service_name.service
echo $odoo_service_file_path
sudo touch $odoo_service_file_path
sudo cp /dev/null $odoo_service_file_path
python3_exec=$(which python3)
if [ $? -eq 0 ]; then
	sudo su root -c "printf '[Unit]\nDescription=Odoo14\n' >> $odoo_service_file_path"
	sudo su root -c "printf 'Requires=postgresql.service\n' >> $odoo_service_file_path"
	sudo su root -c "printf 'After=network.target postgresql.service\n' >> $odoo_service_file_path"
	sudo su root -c "printf '[Service]\nType=simple\n' >> $odoo_service_file_path"
	sudo su root -c "printf 'SyslogIdentifier=$odoo_service_name\n' >> $odoo_service_file_path"
    sudo su root -c "printf 'PermissionsStartOnly=true\n' >> $odoo_service_file_path"	
	sudo su root -c "printf 'User=$odoo_user\nGroup=$odoo_user\n' >> $odoo_service_file_path"
	sudo su root -c "printf 'ExecStart=$python3_exec $odoo_server_location/odoo-bin -c $odoo_config_file\n' >> $odoo_service_file_path"
	sudo su root -c "printf 'StandardOutput=journal+console\n' >> $odoo_service_file_path"
	sudo su root -c "printf '[Install]\nWantedBy=multi-user.target' >> $odoo_service_file_path"
fi

sudo systemctl daemon-reload
sudo systemctl enable --now $odoo_service_name
sudo systemctl status $odoo_service_name

cd ~

rm -rf $installation_dir

echo "Done!!!"

