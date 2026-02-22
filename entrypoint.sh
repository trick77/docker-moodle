#!/bin/bash
set -e

mkdir -p /var/moodledata
chown -R www-data:www-data /var/moodledata
chmod 0750 /var/moodledata

# Copy custom plugins into the Moodle installation
PLUGIN_SRC="/docker-plugins"
MOODLE_ROOT="/var/www/html/public"

if [ -d "$PLUGIN_SRC" ]; then
    for type_dir in "$PLUGIN_SRC"/*/; do
        [ -d "$type_dir" ] || continue
        if [ -L "$type_dir" ]; then
            echo "WARNING: Skipping symlink plugin type directory: $type_dir"
            continue
        fi
        type_name=$(basename "$type_dir")
        for plugin_dir in "$type_dir"*/; do
            [ -d "$plugin_dir" ] || continue
            if [ -L "$plugin_dir" ]; then
                echo "WARNING: Skipping symlink plugin directory: $plugin_dir"
                continue
            fi
            plugin_name=$(basename "$plugin_dir")
            dest="$MOODLE_ROOT/$type_name/$plugin_name"
            echo "Installing plugin: $type_name/$plugin_name -> $dest"
            cp -r "$plugin_dir" "$dest"
            chown -R www-data:www-data "$dest"
        done
    done
fi

service cron start

if ! php /var/www/html/admin/cli/install_database.php \
    --agree-license \
    --fullname="${MOODLE_SITE_NAME}" \
    --shortname="moodle" \
    --adminpass="${MOODLE_INSTALL_ADMIN_PASS}" \
    --adminemail="${MOODLE_INSTALL_ADMIN_EMAIL}" 2>&1; then
    echo "Note: install_database.php exited non-zero (DB may already be installed)"
fi

chown -R www-data:www-data /var/moodledata

exec apache2-foreground
