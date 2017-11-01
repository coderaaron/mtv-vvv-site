<?php
/**
 * The base configuration for WordPress
 *
 * The wp-config.php creation script uses this file during the
 * installation. You don't have to use the web site, you can
 * copy this file to "wp-config.php" and fill in the values.
 *
 * This file contains the following configurations:
 *
 * * MySQL settings
 * * Secret keys
 * * Database table prefix
 * * ABSPATH
 *
 * @link https://codex.wordpress.org/Editing_wp-config.php
 *
 * @package WordPress
 */

/*
These are here to make WP CLI happy
require_once(ABSPATH . 'wp-settings.php');
 */
if ( $_SERVER['DOCUMENT_ROOT'] == "/vagrant/www/landlord" ) {
	$_SERVER['DOCUMENT_ROOT'] = getcwd();
}
/* End WP CLI stuff */

// NOTE: this WordPress install is configured for multitenancy
require $_SERVER['DOCUMENT_ROOT'] . '/wp-config.php';
