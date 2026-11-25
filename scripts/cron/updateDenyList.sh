#!/usr/bin/env bash
set -euo pipefail

# defines the path to where the site is located
site_path="/var/www/html"

cd "$site_path"

# refreshes the StopForumSpam IP deny-list cache
/usr/local/bin/php "$site_path/maintenance/run.php" "$site_path/extensions/StopForumSpam/maintenance/updateDenyList.php"
