#!/usr/bin/env bash
# Provision WordPress Stable

DB_NAME="${SITE//./}"
HOSTNAME=$(get_primary_host)

# Make a database, if we don't already have one
echo -e "\nCreating database '${DB_NAME}' (if it's not already there)"
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME}"
mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO wp@localhost IDENTIFIED BY 'wp';"
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
define( 'WP_HOME', 'https://${HOSTNAME}' );
define( 'WP_SITEURL', 'https://${HOSTNAME}/wp' );
define( 'WP_CONTENT_DIR', dirname( __FILE__ ) . '/wp-content' );
define( 'WP_CONTENT_URL', 'https://${HOSTNAME}/wp-content' );

define( 'SCRIPT_DEBUG', true );
define( 'WP_DEBUG', true );
define( 'WP_DEBUG_LOG', true );
PHP

  mv wp/wp-config.php wp-config.php
  sed -i "s/require_once ABSPATH . 'wp-settings.php';/if \( ! \( defined\( 'WP_CLI' \) \&\& WP_CLI \) \) \{ require_once ABSPATH . 'wp-settings.php'; \}/g" wp-config.php

  #echo "Installing WordPress Stable..."
  #noroot wp core install --url=local.wordpress.dev --quiet --path=wp/ --title="Local WordPress Dev" --admin_name=admin --admin_email="admin@local.dev" --admin_password="password"

  cp ${VVV_PATH_TO_SITE}/provision/index.php ${VVV_PATH_TO_SITE}/public_html/index.php

  # Undo the horrible hack
  cd ${VVV_PATH_TO_SITE}/public_html/wp
  mv wp-config.php.orig wp-config.php

fi

echo -e "\n Starting SSL operations.\n\n"

# SSL stuff, still in beta
# 
# 
# NOTE: You need to add the line 'openssl.cafile=/usr/local/share/ca-certificates/rootCA.crt' to /etc/php/7.0/fpm/php.ini (in the Vagrant)
# You also need to double-click on the ${HOSTNAME}.crt and add it to the keychain
# 
# 
# This creates a Root certificate for the "server" to sign all of the site certificates. This only needs to be done once, so we check
# the directory where openssl expects certificates to be located. (/usr/local/share/ca-certificates/)
cd ~
if [[ ! -e "/usr/local/share/ca-certificates/rootCA.crt" ]]; then
  response=`curl -s https://ipinfo.io/json`

  country=`echo $response | sed -e 's/^.*"country"[ ]*:[ ]*"//' -e 's/".*//'`
  region=`echo $response | sed -e 's/^.*"region"[ ]*:[ ]*"//' -e 's/".*//'`
  city=`echo $response | sed -e 's/^.*"city"[ ]*:[ ]*"//' -e 's/".*//'`
  echo -e "\n Creating Root certificate.\n\n"
  cd /vagrant/www/
  openssl genrsa -out rootCA.key 2048
  openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1024 -out rootCA.crt -subj "/C=${country}/ST=${region}/L=${city}/O=LocalDev/OU=VVVdeveloper/emailAddress=vagrant@localhost/CN=vvv.dev"
  sudo cp rootCA.crt /usr/local/share/ca-certificates/
  sudo cp rootCA.key /usr/local/share/ca-certificates/
  sudo update-ca-certificates
fi
# Now create a certificate for this site and sign it with the server's Root certificate created above (or by the first site spun up on this Vagrant)
if [[ ! -e "${VVV_PATH_TO_SITE}/ssl/${HOSTNAME}.crt" ]]; then
  response=`curl -s https://ipinfo.io/json`

  country=`echo $response | sed -e 's/^.*"country"[ ]*:[ ]*"//' -e 's/".*//'`
  region=`echo $response | sed -e 's/^.*"region"[ ]*:[ ]*"//' -e 's/".*//'`
  city=`echo $response | sed -e 's/^.*"city"[ ]*:[ ]*"//' -e 's/".*//'`
  echo -e "\n Creating site SSL certificate.\n\n"
  mkdir -p ${VVV_PATH_TO_SITE}/ssl
  cd ${VVV_PATH_TO_SITE}/ssl
  echo "authorityKeyIdentifier=keyid,issuer" > v3.ext
  echo "basicConstraints=CA:FALSE" >> v3.ext
  echo "keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment" >> v3.ext
  echo "subjectAltName = @alt_names" >> v3.ext
  echo "[alt_names]" >> v3.ext
  echo "DNS.1 = ${HOSTNAME}" >> v3.ext
  
  echo "[req]" > ${HOSTNAME}.csr.cnf
  echo "default_bits = 2048" >> ${HOSTNAME}.csr.cnf
  echo "prompt = no" >> ${HOSTNAME}.csr.cnf
  echo "default_md = sha256" >> ${HOSTNAME}.csr.cnf
  echo "distinguished_name = dn" >> ${HOSTNAME}.csr.cnf
  echo "[dn]" >> ${HOSTNAME}.csr.cnf
  echo "C=${country}" >> ${HOSTNAME}.csr.cnf
  echo "ST=${region}" >> ${HOSTNAME}.csr.cnf
  echo "L=${city}" >> ${HOSTNAME}.csr.cnf
  echo "O=LocalDev" >> ${HOSTNAME}.csr.cnf
  echo "OU=VVVdeveloper" >> ${HOSTNAME}.csr.cnf
  echo "emailAddress=vagrant@localhost" >> ${HOSTNAME}.csr.cnf
  echo "CN=${HOSTNAME}" >> ${HOSTNAME}.csr.cnf

  
  openssl req -new -sha256 -nodes -out ${HOSTNAME}.csr -newkey rsa:2048 -keyout ${HOSTNAME}.key -config <( cat ${HOSTNAME}.csr.cnf )
  openssl x509 -req -in ${HOSTNAME}.csr -CA /usr/local/share/ca-certificates/rootCA.crt -CAkey /usr/local/share/ca-certificates/rootCA.key -CAcreateserial -out ${HOSTNAME}.crt -days 500 -sha256 -extfile v3.ext

  sudo update-ca-certificates
fi

echo -e "\n SSL operations done.\n\n"