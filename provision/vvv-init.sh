#!/usr/bin/env bash
# Provision Multi-tennant WordPress Stable

is_utility_installed() {
  local utilities=$(shyaml get-values "utilities.${1}" 2> /dev/null < ${VVV_CONFIG})
  for utility in ${utilities}; do
    if [[ "${utility}" == "${2}" ]]; then
      return 0
    fi
  done
  return 1
}

set -eo pipefail

echo " * Custom multi-tennant provisioner - downloads and installs a copy of WP stable (if needed) and sets up tennant site"

# fetch the first host as the primary domain. If none is available, generate a default using the site name
DOMAIN=$(get_primary_host "${VVV_SITE_NAME}".test)
SITE_TITLE=$(get_config_value 'site_title' "${DOMAIN}")
WP_VERSION=$(get_config_value 'wp_version' 'latest')
WP_LOCALE=$(get_config_value 'locale' 'en_US')
WP_TYPE=$(get_config_value 'wp_type' "single")
DB_NAME=$(get_config_value 'db_name' "${VVV_SITE_NAME}")
DB_NAME=${DB_NAME//[\\\/\.\<\>\:\"\'\|\?\!\*]/}

# Make a database, if we don't already have one
echo -e " * Creating database '${DB_NAME}' (if it's not already there)"
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`"
echo -e " * Granting the wp user priviledges to the '${DB_NAME}' database"
mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO wp@localhost IDENTIFIED BY 'wp';"
echo -e " * DB operations done."


echo " * Setting up the log subfolder for Nginx logs"
noroot mkdir -p "${VVV_PATH_TO_SITE}/log"
noroot touch "${VVV_PATH_TO_SITE}/log/nginx-error.log"
noroot touch "${VVV_PATH_TO_SITE}/log/nginx-access.log"

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
  ln -s wp/wp-admin/index.php wp-admin

  cd ${VVV_PATH_TO_SITE}/public_html/wp-content
  # Symlink the plugins and themes to the deafult install's plugins and themes
  mkdir ../../../landlord/wp-content/mu-plugins
  ln -s ../../../landlord/wp-content/mu-plugins mu-plugins
  ln -s ../../../landlord/wp-content/plugins plugins
  ln -s ../../../landlord/wp-content/themes themes

  # A horrible hack, but we have to do it
  cd ${VVV_PATH_TO_SITE}/public_html/wp
  mv wp-config.php wp-config.php.orig

  cd ${VVV_PATH_TO_SITE}/public_html

  echo "Configuring WordPress Stable..."
  noroot wp core config --dbname=${DB_NAME} --dbuser=wp --dbpass=wp --quiet --path=wp/ --force --extra-php <<PHP
define( 'WP_HOME', 'https://${DOMAIN}' );
define( 'WP_SITEURL', 'https://${DOMAIN}/wp' );
define( 'WP_CONTENT_DIR', dirname( __FILE__ ) . '/wp-content' );
define( 'WP_CONTENT_URL', 'https://${DOMAIN}/wp-content' );
define( 'FORCE_SSL_ADMIN', true );

define( 'SCRIPT_DEBUG', true );
define( 'WP_DEBUG', true );
define( 'WP_DEBUG_LOG', true );
PHP

  mv wp/wp-config.php wp-config.php
  sed -i "s/require_once ABSPATH . 'wp-settings.php';/if \( ! \( defined\( 'WP_CLI' \) \&\& WP_CLI \) \) \{ require_once ABSPATH . 'wp-settings.php'; \}/g" wp-config.php

  cp ${VVV_PATH_TO_SITE}/provision/index.php ${VVV_PATH_TO_SITE}/public_html/index.php

  # Undo the horrible hack
  cd ${VVV_PATH_TO_SITE}/public_html/wp
  mv wp-config.php.orig wp-config.php

  cd ${VVV_PATH_TO_SITE}/public_html
  noroot wp core install --debug --url="${DOMAIN}" --title="${SITE} Dev" --admin_name=admin --admin_email="admin@local.test" --admin_password="password"
fi

cp -f "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf.tmpl" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"

echo "***** SKIPPING CHECKS *****"

sed -i "s#{{TLS_CERT}}#ssl_certificate /srv/certificates/${VVV_SITE_NAME}/dev.crt;#" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
sed -i "s#{{TLS_KEY}}#ssl_certificate_key /srv/certificates/${VVV_SITE_NAME}/dev.key;#" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
