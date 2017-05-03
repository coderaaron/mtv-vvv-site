#!/usr/bin/env bash
# Provision WordPress Stable

DB_NAME="${SITE//./}"

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
  ln -s ../../../landlord/wp-content/plugins plugins
  ln -s ../../../landlord/wp-content/themes themes

  # A horrible hack, but we have to do it
  cd ${VVV_PATH_TO_SITE}/public_html/wp
  mv wp-config.php wp-config.php.orig

  cd ${VVV_PATH_TO_SITE}/public_html

  echo "Configuring WordPress Stable..."
  noroot wp core config --dbname=${DB_NAME} --dbuser=wp --dbpass=wp --quiet --path=wp/ --force --extra-php <<PHP
define( 'WP_HOME', 'http://' . basename( realpath( __DIR__ . '/..' ) ) );
define( 'WP_SITEURL', 'http://' . basename( realpath( __DIR__ . '/..' ) ) . '/wp' );
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

echo -e "\n Starting SSL operations.\n\n"

# SSL stuff, still in beta
# This creates a Root certificate for the "server" to sign all of the site certificates. This only needs to be done once, so we check
# the directory where openssl expects certificates to be located. (/usr/local/share/ca-certificates/)
cd ~
if [[ ! -e "/usr/local/share/ca-certificates/ca.crt" ]]; then
  cd /vagrant/
  openssl genrsa -out rootCA.key 2048
  openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1024 -out rootCA.pem -subj '/C=US/ST=Missouri/L=Saint Louis/O=WUSM/OU=MPA/emailAddress=vagrant@localhost/CN=vvv.dev'
  sudo cp rootCA.pem /usr/local/share/ca-certificates/
  sudo cp rootCA.key /usr/local/share/ca-certificates/
  sudo update-ca-certificates
fi
# Now create a certificate for this site and sign it with the server's Root certificate created above (or by the first site spun up on this Vagrant)
if [[ ! -e "/usr/local/share/ca-certificates/${SITE}.crt" ]]; then
  mkdir -p ${VVV_PATH_TO_SITE}/ssl
  cp ${VVV_PATH_TO_SITE}/provision/server-template.csr.cnf ${VVV_PATH_TO_SITE}/ssl/${SITE}.csr.cnf
  cd ${VVV_PATH_TO_SITE}/ssl
  echo "authorityKeyIdentifier=keyid,issuer" > v3.ext
  echo "basicConstraints=CA:FALSE" >> v3.ext
  echo "keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment" >> v3.ext
  echo "subjectAltName = @alt_names" >> v3.ext
  echo "[alt_names]" >> v3.ext
  echo "DNS.1 = ${SITE}" >> v3.ext
  
  openssl req -new -sha256 -nodes -out ${SITE}.csr -newkey rsa:2048 -keyout ${SITE}.key -config <( cat ${SITE}.csr.cnf )
  openssl x509 -req -in ${SITE}.csr -CA /vagrant/rootCA.pem -CAkey /vagrant/rootCA.key -CAcreateserial -out ${SITE}.crt -days 500 -sha256 -extfile v3.ext

  sudo cp ${SITE}.crt /usr/local/share/ca-certificates/
  sudo update-ca-certificates
fi

echo -e "\n SSL operations done.\n\n"