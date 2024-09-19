#!/bin/bash

# Laravel Deployment Script
# Author: Patrick Mamsery
# Version: 1.0.1
# Description: This script automates the deployment of Laravel applications to a server, supporting both Apache and Nginx.

# Color codes for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display progress
progress() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to display success messages
success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to display error messages
error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display warnings
warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to ask yes/no questions
ask_yes_no() {
    while true; do
        read -p "$1 (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Welcome message and script introduction
clear
echo -e "${GREEN}=================================${NC}"
echo -e "${GREEN}   Laravel Deployment Script     ${NC}"
echo -e "${GREEN}=================================${NC}"
echo -e "Author: Patrick Mamsery"
echo -e "Version: 1.1.0\n"
echo -e "This script will guide you through the process of deploying a Laravel application to your server."
echo -e "Please make sure you have the necessary information ready before proceeding.\n"
echo -e "If you find this script helpful, please consider starring the GitHub repository!"
echo -e "GitHub: https://github.com/PatrickMamsery/laravel-deployment-script\n"

if ask_yes_no "Would you like to star the repository now?"; then
    echo -e "Great! Please visit https://github.com/PatrickMamsery/laravel-deployment-script and click the star button."
    echo -e "Press any key to continue when you're done."
    read -n 1 -s
fi

echo -e "\nLet's get started with the deployment process!\n"

# Ask for the project directory path or use a fallback path
read -p "Enter the absolute path to the project directory (or press Enter to use the default path '/var/www'): " PROJECT_PATH

# Use the fallback path if the user doesn't provide one
if [ -z "$PROJECT_PATH" ]; then
    PROJECT_PATH="/var/www"
fi

# Ask for the SSH URL of the GitHub repository
read -p "Enter the SSH URL of your GitHub repository: " REPO_URL

# Extract the repository name from the URL
REPO_NAME=$(basename -s .git $REPO_URL)

# Ask for the server's SSH IP address and username
read -p "Enter the server's SSH IP address: " SERVER_IP
read -p "Enter the SSH username: " SSH_USER

# Ask for the Laravel environment and app key
read -p "Enter the Laravel environment (e.g., local, production, development): " APP_ENV
read -p "Enter the Laravel app key (leave empty to generate a new one): " APP_KEY

# Ask for the desired PHP version
read -p "Enter the desired PHP version (e.g., 7.4, 8.0): " PHP_VERSION

# Ask for the web server type
read -p "Enter the web server type (apache/nginx): " WEB_SERVER
WEB_SERVER=$(echo "$WEB_SERVER" | tr '[:upper:]' '[:lower:]')

# Validate web server input
if [[ "$WEB_SERVER" != "apache" && "$WEB_SERVER" != "nginx" ]]; then
    error "Invalid web server type. Please choose either 'apache' or 'nginx'. Exiting."
    exit 1
fi

# Ask if a MySQL database should be created
if ask_yes_no "Do you want to create a MySQL database on the server?"; then
    CREATE_DB="y"
else
    CREATE_DB="n"
fi

# Check for PHP version format and set the PHP package name accordingly
if [[ "$PHP_VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
    PHP_PACKAGE="php$PHP_VERSION"
else
    error "Invalid PHP version format. Exiting."
    exit 1
fi

# Install required packages
progress "Checking for required packages..."
ssh $SSH_USER@$SERVER_IP << EOF
    sudo apt-get update
    sudo apt-get -y upgrade
    
    if [ "$WEB_SERVER" = "nginx" ]; then
        sudo apt-get -y install nginx
    elif [ "$WEB_SERVER" = "apache" ]; then
        sudo apt-get -y install apache2
    fi

    sudo apt-get -y install git curl unzip

    # Check and install PHP and required extensions
    php_packages=("$PHP_PACKAGE-fpm" "$PHP_PACKAGE-mysql" "$PHP_PACKAGE-cli" "$PHP_PACKAGE-common" "$PHP_PACKAGE-zip" "$PHP_PACKAGE-mbstring" "$PHP_PACKAGE-xml" "$PHP_PACKAGE-json" "$PHP_PACKAGE-curl" "$PHP_PACKAGE-gd" "$PHP_PACKAGE-imagick" "$PHP_PACKAGE-bcmath" "$PHP_PACKAGE-pdo" "$PHP_PACKAGE-tokenizer")

    for package in "${php_packages[@]}"; do
        if ! dpkg -l | grep -q "$package"; then
            sudo apt-get -y install "$package"
        fi
    done

    # Check if Composer is installed
    if ! which composer > /dev/null 2>&1; then
        # Install Composer locally within the project folder
        cd $PROJECT_PATH
        curl -sS https://getcomposer.org/installer | php
        sudo mv composer.phar /usr/local/bin/composer
        sudo chmod +x /usr/local/bin/composer
    fi
EOF

success "Required packages installed successfully."

# Clone the GitHub repository
progress "Cloning the GitHub repository..."
ssh $SSH_USER@$SERVER_IP "git clone $REPO_URL $PROJECT_PATH/$REPO_NAME"
success "GitHub repository cloned successfully."

# Create a .env file
progress "Creating .env file..."
ssh $SSH_USER@$SERVER_IP << EOF
    cd $PROJECT_PATH/$REPO_NAME
    cp .env.example .env

    # Set the Laravel environment
    sed -i "s/APP_ENV=.*/APP_ENV=$APP_ENV/" .env
EOF
success ".env file created and configured."

# Create MySQL database and user on the server
if [ "$CREATE_DB" = "y" ] || [ "$CREATE_DB" = "Y" ]; then
    # Ask for the MySQL database name
    read -p "Enter the MySQL database name: " DB_NAME

    # Ask for the MySQL root password
    read -s -p "Enter the MySQL root password: " DB_ROOT_PASSWORD
    echo
    progress "Creating MySQL database and user on the server..."

    ssh $SSH_USER@$SERVER_IP << EOF
        # Create the MySQL database
        mysql -u root -p$DB_ROOT_PASSWORD -e "CREATE DATABASE $DB_NAME;"

        # Ask if a new MySQL user should be created
        if ask_yes_no "Do you want to create a new MySQL user for the application?"; then
            # Ask for the MySQL user name and password
            read -p "Enter the MySQL user name: " DB_USER
            read -s -p "Enter the MySQL user password: " DB_USER_PASSWORD
            echo # Newline for clarity

            # Create the MySQL user and grant privileges
            mysql -u root -p$DB_ROOT_PASSWORD -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_USER_PASSWORD';"
            mysql -u root -p$DB_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
            mysql -u root -p$DB_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"
        fi
EOF
    success "MySQL database and user created successfully."
fi

# Run composer install/update
progress "Running composer install or update..."
ssh $SSH_USER@$SERVER_IP << EOF
    cd $PROJECT_PATH/$REPO_NAME
    composer install --optimize-autoloader --no-dev

    # Set permissions for Laravel storage and cache directories
    sudo chown -R www-data:www-data $PROJECT_PATH/$REPO_NAME/storage
    sudo chown -R www-data:www-data $PROJECT_PATH/$REPO_NAME/bootstrap/cache

    # Populate the .env file with database credentials
    sed -i "s/DB_DATABASE=.*/DB_DATABASE=$DB_NAME/" .env
    
    # If a new MySQL user was created, use the new credentials else use the root credentials
    if [ "$CREATE_DB_USER" = "y" ] || [ "$CREATE_DB_USER" = "Y" ]; then
        sed -i "s/DB_USERNAME=.*/DB_USERNAME=$DB_USER/" .env
        sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_USER_PASSWORD/" .env
    else
        sed -i "s/DB_USERNAME=.*/DB_USERNAME=root/" .env
        sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_ROOT_PASSWORD/" .env
    fi

    # Generate or set the app key
    if [ -z "$APP_KEY" ]; then
        php artisan key:generate
    else
        sed -i "s/APP_KEY=.*/APP_KEY=$APP_KEY/" .env
    fi
EOF
success "Composer dependencies installed and Laravel configured."

# Optionally run migrations and seeders
if ask_yes_no "Do you want to run migrations and seeders?"; then
    progress "Running migrations and seeders..."
    ssh $SSH_USER@$SERVER_IP << EOF
        cd $PROJECT_PATH/$REPO_NAME
        php artisan migrate --seed
EOF
    success "Migrations and seeders executed successfully."
fi

# Create web server configuration on the server
read -p "Enter the domain name for the site (e.g., example.com): " DOMAIN_NAME

progress "Creating $WEB_SERVER configuration on the server..."

if [ "$WEB_SERVER" = "nginx" ]; then
    config_file="/etc/nginx/sites-available/$REPO_NAME"
    config_content=$(cat <<EOF
server {
    server_name $DOMAIN_NAME;
    root $PROJECT_PATH/$REPO_NAME/public;

    index index.php index.html index.htm;

    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF
)
    ssh $SSH_USER@$SERVER_IP << EOF
        echo '$config_content' | sudo tee '$config_file'
        sudo ln -s '$config_file' /etc/nginx/sites-enabled/
        sudo nginx -t && sudo systemctl reload nginx
EOF
elif [ "$WEB_SERVER" = "apache" ]; then
    config_file="/etc/apache2/sites-available/$REPO_NAME.conf"
    config_content=$(cat <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN_NAME
    ServerAdmin webmaster@localhost
    DocumentRoot $PROJECT_PATH/$REPO_NAME/public

    <Directory $PROJECT_PATH/$REPO_NAME/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/$REPO_NAME-error.log
    CustomLog \${APACHE_LOG_DIR}/$REPO_NAME-access.log combined
</VirtualHost>
EOF
)
    ssh $SSH_USER@$SERVER_IP << EOF
        echo '$config_content' | sudo tee '$config_file'
        sudo a2ensite $REPO_NAME.conf
        sudo a2enmod rewrite
        sudo apache2ctl configtest && sudo systemctl reload apache2
EOF
fi

success "$WEB_SERVER configuration created and applied."

# Optionally create a Let's Encrypt SSL certificate
if ask_yes_no "Do you want to create a Let's Encrypt SSL certificate?"; then
    progress "Creating a Let's Encrypt SSL certificate..."
    ssh $SSH_USER@$SERVER_IP << EOF
        sudo apt-get update
        sudo apt-get install -y certbot
        if [ "$WEB_SERVER" = "nginx" ]; then
            sudo apt-get install -y python3-certbot-nginx
            sudo certbot --nginx -d $DOMAIN_NAME
        elif [ "$WEB_SERVER" = "apache" ]; then
            sudo apt-get install -y python3-certbot-apache
            sudo certbot --apache -d $DOMAIN_NAME
        fi
EOF
    success "Let's Encrypt SSL certificate created and installed."
fi

# Deployment complete
success "Deployment completed successfully!"
echo -e "\nYour Laravel application is now deployed and accessible at: http://$DOMAIN_NAME"
echo -e "If you created an SSL certificate, you can also access it via: https://$DOMAIN_NAME"
echo -e "\nThank you for using the Laravel Deployment Script!"
echo -e "If you found this script helpful, please consider starring the GitHub repository:"
echo -e "https://github.com/PatrickMamsery/laravel-deployment-script"
echo -e "\nHave a great day!"