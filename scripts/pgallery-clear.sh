#!/bin/bash

set -e

su -s /bin/bash - www-data -c "cd /var/www/html/gallery \
    && php artisan view:clear \
    && php artisan route:clear \
    && php artisan cache:clear \
    && php artisan route:cache"

exec "$@"
