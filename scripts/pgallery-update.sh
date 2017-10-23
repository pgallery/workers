#!/bin/bash

set -e

su -s /bin/bash - www-data -c "cd /var/www/html/gallery \
    && git pull \
    && composer update \
    && php artisan migrate \
    && php artisan view:clear \
    && php artisan route:clear \
    && php artisan cache:clear \
    && php artisan route:cache"

exec "$@"
