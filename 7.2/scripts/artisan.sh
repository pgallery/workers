#!/bin/bash

set -e

su -s /bin/bash - www-data -c "cd /var/www/html/gallery \
    && php artisan $@"

