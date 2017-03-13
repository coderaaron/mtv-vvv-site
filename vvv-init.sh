#!/usr/bin/env bash
# Provision WordPress Stable

# Make a database, if we don't already have one
echo -e "\nCreating database 'vvvtest' (if it's not already there)"
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS vvvtest"
mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON vvvtest.* TO wp@localhost IDENTIFIED BY 'wp';"
echo -e "\n DB operations done.\n\n"

# Nginx Logs
mkdir -p ${VVV_PATH_TO_SITE}/log
touch ${VVV_PATH_TO_SITE}/log/error.log
touch ${VVV_PATH_TO_SITE}/log/access.log

# Set up our tenant's landlord
if [[ ! -d "${VVV_PATH_TO_SITE}/../landlord" ]]; then
  echo "Downloading WordPress Landlord, see http://wordpress.org/"
  cd ${VVV_PATH_TO_SITE}
  cd ..
  curl -L -O "https://wordpress.org/latest.tar.gz"
  noroot tar -xvf latest.tar.gz
  mv wordpress landlord
  rm latest.tar.gz
  
  noroot cp ${VVV_PATH_TO_SITE}/provision/landlord-wp-config.php ${VVV_PATH_TO_SITE}/../landlord/wp-config.php 
fi

# Install and configure the latest stable version of WordPress
if [[ ! -d "${VVV_PATH_TO_SITE}/public_html" ]]; then

  # Make the public_html folder and wp-content folder (if they weren't already manually created)
  # The uploads folder needs to be local to this tenant, but creating it with the -p flag
  # will also create the two parent folders
  mkdir -p ${VVV_PATH_TO_SITE}/public_html/wp-content/uploads
  cd ${VVV_PATH_TO_SITE}/public_html
  # Symlink to the main WordPress installation
  ln -s ../../landlord wp

  cd ${VVV_PATH_TO_SITE}/public_html/wp-content
  # Symlink the plugins and themes to the deafult install's plugins and themes
  ln -s ../../../landlord/wp-content/plugins plugins
  ln -s ../../../landlord/wp-content/themes themes

  # A horrible hack, but we have to do it
  cd ${VVV_PATH_TO_SITE}/public_html/wp
  mv wp-config.php wp-config.php.orig

  cd ${VVV_PATH_TO_SITE}/public_html

  echo "Configuring WordPress Stable..."
  noroot wp core config --dbname=vvvtest --dbuser=wp --dbpass=wp --quiet --path=wp/ --force --extra-php <<PHP
define( 'WP_HOME', 'http://' . basename( realpath( __DIR__ . '/..' ) ) . '.dev' );
define( 'WP_SITEURL', 'http://' . basename( realpath( __DIR__ . '/..' ) ) . '.dev/wp' );
define( 'WP_CONTENT_DIR', dirname( __FILE__ ) . '/wp-content' );
define( 'WP_CONTENT_URL', 'https://' . \$_SERVER['HTTP_HOST'] . '/wp-content' );

define( 'WP_DEBUG', true );
PHP
  mv wp/wp-config.php wp-config.php

  #echo "Installing WordPress Stable..."
  #noroot wp core install --url=local.wordpress.dev --quiet --path=wp/ --title="Local WordPress Dev" --admin_name=admin --admin_email="admin@local.dev" --admin_password="password"

  cp ${VVV_PATH_TO_SITE}/provision/index.php ${VVV_PATH_TO_SITE}/public_html/index.php

  # Undo the horrible hack
  cd ${VVV_PATH_TO_SITE}/public_html/wp
  mv wp-config.php.orig wp-config.php

fi