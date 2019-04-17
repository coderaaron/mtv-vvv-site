# MTVVV

**A Multitenant VVV setup (Now with Auto-install!!!)**

MTVVV is a site configuration for use with [VVV](https://varyingvagrantvagrants.org/). It's based off the talk I gave at WordCamp St. Louis which in turn was based on a talk a WPCampus by [Cliff Seal](https://www.youtube.com/watch?v=88cMYrr4-5o).

## Why?

If you're developing a plugin or theme that you want to test on multiple types of sites, MTVVV is ideal for that.

With MTVVV, you get the best of both WordPress Multisite and WordPress single sites. While each site is separated out with its own database and uploads directory, there's only one set of WordPress core files, themes, and plugins to maintain and update. If you update WordPress core, a theme, or plugin on one, it will extend to everything else. It also creates an SSL certificate for your locally hosted sites for future-proofing and easy `https` testing.

## Basics

The master copy of the WordPress core, plugins, and themes are located at:

> `vagrant-local/www/landlord`

Each site is symlinked to each of those folders. Beyond that, each site has its own folder within:

> `vagrant-local/www`

Uploads for each site are stored at:

> `vagrant-local/www/[site-name]/public_html/wp-content/uploads`

## Instructions

**NOTE**: This is super important. This does not work with VVV 2.0.0. You must be running version 2.1.0 or higher.

Install [Vagrant](https://www.vagrantup.com/downloads.html) and [VVV](https://varyingvagrantvagrants.org/docs/en-US/installation/software-requirements/) first. Don't forget to install the relevant Vagrant plugins as indicated on the VVV Software Requirements page.

Follow the instructions on the VVV documentation page for [adding a new site](https://varyingvagrantvagrants.org/docs/en-US/adding-a-new-site/) and set the 'repo:' argument to `https://github.com/coderaaron/mtv-vvv-site.git`. The sites listing in `vvv-custom.yml` should look something like this:

```
---
sites:
    testbed:
        repo: https://github.com/coderaaron/mtv-vvv-site.git
        hosts:
            - testbed.local
    playground:
        repo: https://github.com/coderaaron/mtv-vvv-site.git
        hosts:
            - playground.local
```

**NOTE**: Each new site must be separated out. You cannot add news hosts to each site entry and have it act as a new WordPress installation.

Run `vagrant provision` after saving out `vvv-custom.yml`. Do this for as many sites as you need.

## Add VVV as trusted certificate authority to your computer

### (The MUCH simplified version)

Follow the VVV instructions on [setting up HTTPS](https://varyingvagrantvagrants.org/docs/en-US/references/https/) and [trusting the certificate authority](https://varyingvagrantvagrants.org/docs/en-US/references/https/trusting-ca/) and you should be good to go.
