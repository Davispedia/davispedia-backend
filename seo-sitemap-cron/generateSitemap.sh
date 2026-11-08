#!/usr/bin/env bash

# defines the path to where the site is located
site_path="/var/www/html"

# creates sitemap directory if not already exists
mkdir -p "$site_path/sitemap"
         
# mediawiki script that updates XML
php "$site_path/maintenance/generateSitemap.php" --server=https://davispedia.org --fspath="$site_path/sitemap/"  

