#!/bin/bash

# Welcome message
echo "Welcome to the Laravel deployment script."

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

# Ask if a MySQL database should be created
read -p "Do you want to create a MySQL database on the server? (y/n): " CREATE_DB

# Check for PHP version format and set the PHP package name accordingly
if [[ "$PHP_VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
    PHP_PACKAGE="php$PHP_VERSION"
else
    echo "Invalid PHP version format. Exiting."
    exit 1
fi

# Install required packages
echo "Checking for required packages..."
ssh $SSH_USER@$SERVER_IP << EOF
    if ! dpkg -l | grep -q "nginx"; then
        sudo apt-get update
        sudo apt-get -y upgrade
        sudo apt-get -y install nginx
    fi

    if ! dpkg -l | grep -q "git"; then
        sudo apt-get -y install git
    fi

    if ! dpkg -l | grep -q "curl"; then
        sudo apt-get -y install curl
    fi

    if ! dpkg -l | grep -q "unzip"; then
        sudo apt-get -y install unzip
    fi

    # Check and install PHP and required extensions
    php_packages=("php-fpm" "php-mysql" "php-cli" "php-common" "php-zip" "php-mbstring" "php-xml" "php-json" "php-curl" "php-gd" "php-imagick" "php-bcmath" "php-pdo" "php-tokenizer" "php-json")

    for package in "${php_packages[@]}"; do
        if ! dpkg -l | grep -q "$package"; then
            sudo apt-get -y install "$package"
        fi
    done

    # Check if Composer is installed
    if ! which composer > /dev/null 2>&1; then
        # Install Composer locally within the project folder
        cd $PROJECT_PATH
        git clone https://github.com/composer/getcomposer.org.git
        cd getcomposer.org
        php getcomposer.org
        mv composer.phar $PROJECT_PATH/$REPO_NAME/composer.phar
        cd ..
        rm -rf getcomposer.org
    fi
EOF

# Clone the GitHub repository
echo "Cloning the GitHub repository..."
ssh $SSH_USER@$SERVER_IP "git clone $REPO_URL $PROJECT_PATH/$REPO_NAME"

# Create a .env file
echo "Creating .env file..."
ssh $SSH_USER@$SERVER_IP << EOF
    cd $PROJECT_PATH/$REPO_NAME
    cp .env.example .env

    # Set the Laravel environment
    sed -i "s/APP_ENV=.*/APP_ENV=$APP_ENV/" .env
EOF

# Create MySQL database and user on the server
if [ "$CREATE_DB" = "y" ] || [ "$CREATE_DB" = "Y" ]; then

    # Ask for the MySQL database name
    read -p "Enter the MySQL database name: " DB_NAME

    # Ask for the MySQL root password
    read -s -p "Enter the MySQL root password: " DB_ROOT_PASSWORD
    echo "Creating MySQL database and user on the server..."

    ssh $SSH_USER@$SERVER_IP << EOF
        # Create the MySQL database
        mysql -u root -p$DB_ROOT_PASSWORD -e "CREATE DATABASE $DB_NAME;"

        # Ask if a new MySQL user should be created
        read -p "Do you want to create a new MySQL user for the application? (y/n): " CREATE_DB_USER

        if [ "$CREATE_DB_USER" = "y" ] || [ "$CREATE_DB_USER" = "Y" ]; then
            # Ask for the MySQL user name and password
            read -p "Enter the MySQL user name: " DB_USER
            read -s -p "Enter the MySQL user password: " DB_USER_PASSWORD
            echo # Newline for clarity

            # Create the MySQL user and grant privileges
            mysql -u root -p -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_USER_PASSWORD';"
            mysql -u root -p -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
            mysql -u root -p -e "FLUSH PRIVILEGES;"
        fi
EOF
fi

# Run composer install/update
echo "Running composer install or update..."
ssh $SSH_USER@$SERVER_IP << EOF
    cd $PROJECT_PATH/$REPO_NAME

    if [ -f composer.phar ]; then
        # Use locally installed Composer
        php composer.phar install --optimize-autoloader --no-dev
    else
        # Use globally installed Composer
        composer install --optimize-autoloader --no-dev
    fi

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

# Optionally run migrations and seeders
read -p "Do you want to run migrations and seeders? (y/n): " RUN_MIGRATIONS

if [ "$RUN_MIGRATIONS" = "y" ] || [ "$RUN_MIGRATIONS" = "Y" ]; then
    echo "Running migrations and seeders..."
    ssh $SSH_USER@$SERVER_IP << EOF
        cd $PROJECT_PATH/$REPO_NAME
        php artisan migrate --seed
EOF
fi

# Create Nginx server block configuration on the server
read -p "Enter the domain name for the site (e.g., example.com): " DOMAIN_NAME

echo "Creating Nginx server block configuration on the server..."
nginx_config="/etc/nginx/sites-available/$REPO_NAME"

# Define the Nginx server block configuration using a here document
nginx_config_content=$(cat <<EOF
server {
    server_name $DOMAIN_NAME;
    root $PROJECT_PATH/$REPO_NAME/public;

    index index.php index.html index.htm ;

    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock; # Adjust for your PHP version
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

# Create the Nginx server block configuration file on the server
ssh $SSH_USER@$SERVER_IP "echo '$nginx_config_content' | sudo tee '$nginx_config'"

# Create a symbolic link to enable the site on the server
ssh $SSH_USER@$SERVER_IP "sudo ln -s '$nginx_config' /etc/nginx/sites-enabled/"

# Test Nginx configuration and reload on the server
ssh $SSH_USER@$SERVER_IP "sudo nginx -t"
ssh $SSH_USER@$SERVER_IP "sudo systemctl reload nginx"

# Optionally create a Let's Encrypt SSL certificate
read -p "Do you want to create a Let's Encrypt SSL certificate? (y/n): " CREATE_SSL_CERT

if [ "$CREATE_SSL_CERT" = "y" ] || [ "$CREATE_SSL_CERT" = "Y" ]; then
    echo "Creating a Let's Encrypt SSL certificate..."
    ssh $SSH_USER@$SERVER_IP << EOF
        # sudo apt-get -y install certbot python3-certbot-nginx
        # sudo certbot --nginx -d $DOMAIN_NAME
        sudo certbot -d $DOMAIN_NAME
EOF
fi

# Deployment complete
echo "Deployment completed successfully!"
