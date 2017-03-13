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

# Install and configure the latest stable version of WordPress
if [[ ! -d "${VVV_PATH_TO_SITE}/public_html" ]]; then

  # Make the public_html folder and wp-content folder (if they weren't already manually created)
  # The uploads folder needs to be local to this tenant, but creating it with the -p flag
  # will also create the two parent folders
  mkdir -r ${VVV_PATH_TO_SITE}/public_html/wp-content/uploads
  cd ${VVV_PATH_TO_SITE}/public_html
  # Symlink to the main WordPress installation
  ln -s ../../wordpress-default/public_html wp

  cd ${VVV_PATH_TO_SITE}/public_html/wp-content
  # Symlink the plugins and themes to the deafult install's plugins and themes
  ln -s ../../../wordpress-default/public_html/wp-content/plugins plugins
  ln -s ../../../wordpress-default/public_html/wp-content/themes themes


  echo "Configuring WordPress Stable..."
  noroot wp core config --dbname=vvvtest --dbuser=wp --dbpass=wp --quiet --extra-php <<PHP
// Match any requests made via xip.io.
if ( isset( \$_SERVER['HTTP_HOST'] ) && preg_match('/^(local.wordpress.)\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(.xip.io)\z/', \$_SERVER['HTTP_HOST'] ) ) {
    define( 'WP_HOME', 'http://' . \$_SERVER['HTTP_HOST'] );
    define( 'WP_SITEURL', 'http://' . \$_SERVER['HTTP_HOST'] );
}

define( 'WP_DEBUG', true );
PHP

  echo "Installing WordPress Stable..."
  noroot wp core install --url=local.wordpress.dev --quiet --title="Local WordPress Dev" --admin_name=admin --admin_email="admin@local.dev" --admin_password="password"

else

  # echo "Updating WordPress Stable..."
  # cd ${VVV_PATH_TO_SITE}/public_html
  # noroot wp core update

fi