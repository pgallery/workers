#!/bin/bash

set -e

PHPINI=/usr/local/etc/php/php.ini

# php environment
PHP_ALLOW_URL_FOPEN=${PHP_ALLOW_URL_FOPEN:-On}
PHP_DISPLAY_ERRORS=${PHP_DISPLAY_ERRORS:-Off}
PHP_MAX_EXECUTION_TIME=${PHP_MAX_EXECUTION_TIME:-360}
PHP_MAX_INPUT_TIME=${PHP_MAX_INPUT_TIME:-360}
PHP_MEMORY_LIMIT=${PHP_MEMORY_LIMIT:-256}
PHP_POST_MAX_SIZE=${PHP_POST_MAX_SIZE:-256}
PHP_SHORT_OPEN_TAG=${PHP_SHORT_OPEN_TAG:-On}
PHP_TIMEZONE=${PHP_TIMEZONE:-Europe/Moscow}
PHP_UPLOAD_MAX_FILEZIZE=${PHP_UPLOAD_MAX_FILEZIZE:-256}
PHP_MAX_FILE_UPLOADS=${PHP_MAX_FILE_UPLOADS:-250}

WORKERS_NUMBER=${WORKERS_NUMBER:-4}

PHP_TZ=`echo ${PHP_TIMEZONE} |sed  's|\/|\\\/|g'`

# set timezone
ln -snf /usr/share/zoneinfo/${PHP_TIMEZONE} /etc/localtime
dpkg-reconfigure -f noninteractive tzdata

sed -i -e "s/WORKERS_NUMBER/${WORKERS_NUMBER}/g" /etc/supervisord.conf

if [ -f /var/www/html/config/php/php.ini ]; then
    cp /var/www/html/config/php/php.ini ${PHPINI}
else

    sed -i \
        -e "s/memory_limit = 128M/memory_limit = ${PHP_MEMORY_LIMIT}M/g" \
        -e "s/short_open_tag = Off/short_open_tag = ${PHP_SHORT_OPEN_TAG}/g" \
        -e "s/upload_max_filesize = 2M/upload_max_filesize = ${PHP_UPLOAD_MAX_FILEZIZE}M/g" \
        -e "s/max_file_uploads = 20/max_file_uploads = ${PHP_MAX_FILE_UPLOADS}/g" \
        -e "s/max_execution_time = 30/max_execution_time = ${PHP_MAX_EXECUTION_TIME}/g" \
        -e "s/max_input_time = 60/max_input_time = ${PHP_MAX_INPUT_TIME}/g" \
        -e "s/display_errors = Off/display_errors = ${PHP_DISPLAY_ERRORS}/g" \
        -e "s/post_max_size = 8M/post_max_size = ${PHP_POST_MAX_SIZE}M/g" \
        -e "s/allow_url_fopen = On/allow_url_fopen = ${PHP_ALLOW_URL_FOPEN}/g" \
        -e "s/;date.timezone =/date.timezone = ${PHP_TZ}/g" \
        ${PHPINI}

fi

usermod -s /bin/bash www-data
chown www-data:www-data /var/www -R

if [ ! -f /var/www/html/install.lock ]; then

    BRANCH=${BRANCH:-master}

    DB_PORT=${DB_PORT:-3306}
    DB_CONNECTION=${DB_CONNECTION:-mysql}
    MEMCACHED_PORT=${MEMCACHED_PORT:-11211}

    REDIS_PORT=${REDIS_PORT:-6379}
    REDIS_PASSWORD=${REDIS_PASSWORD:-null}

    IMAGE_DRIVER=${IMAGE_DRIVER:-imagick}

    RABBITMQ_PORT=${RABBITMQ_PORT:-5672}
    RABBITMQ_VHOST=${RABBITMQ_VHOST:-/}
    RABBITMQ_LOGIN=${RABBITMQ_LOGIN:-guest}
    RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD:-guest}

    QUEUE_DRIVER=${QUEUE_DRIVER:-database}
    CACHE_DRIVER=${CACHE_DRIVER:-file}
    SESSION_DRIVER=${SESSION_DRIVER:-file}

    su -s /bin/bash - www-data -c "cd /var/www/html/ && git clone -b ${BRANCH} --single-branch https://github.com/pgallery/gallery && \
        cd /var/www/html/gallery && composer install && composer update && cp .env.example .env && \
        php artisan key:generate"

    sed -i \
        -e "s/APP_URL=http:\/\/localhost/APP_URL=http:\/\/${URL}/g" \
        -e "s/APP_TIMEZONE=Europe\/Moscow/APP_TIMEZONE=${PHP_TZ}/g" \
        -e "s/DB_CONNECTION=mysql/DB_CONNECTION=${DB_CONNECTION}/g" \
        -e "s/DB_HOST=127.0.0.1/DB_HOST=${DB_HOST}/g" \
        -e "s/DB_PORT=3306/DB_PORT=${DB_PORT}/g" \
        -e "s/DB_DATABASE=homestead/DB_DATABASE=${DB_DATABASE}/g" \
        -e "s/DB_USERNAME=homestead/DB_USERNAME=${DB_USERNAME}/g" \
        -e "s/DB_PASSWORD=secret/DB_PASSWORD=${DB_PASSWORD}/g" \
        -e "s/IMAGE_DRIVER=gd/IMAGE_DRIVER=${IMAGE_DRIVER}/g" \
        -e "s/CACHE_DRIVER=file/CACHE_DRIVER=${CACHE_DRIVER}/g" \
        -e "s/SESSION_DRIVER=file/SESSION_DRIVER=${SESSION_DRIVER}/g" \
        -e "s/QUEUE_DRIVER=sync/QUEUE_DRIVER=${QUEUE_DRIVER}/g" \
        /var/www/html/gallery/.env

    if [ -n ${MEMCACHED_HOST} ]; then
        sed -i \
            -e "s/MEMCACHED_HOST=/MEMCACHED_HOST=${MEMCACHED_HOST}/g" \
            -e "s/MEMCACHED_PORT=/MEMCACHED_PORT=${MEMCACHED_PORT}/g" \
            -e "s/MEMCACHED_USERNAME=/MEMCACHED_USERNAME=${MEMCACHED_USERNAME}/g" \
            -e "s/MEMCACHED_PASSWORD=/MEMCACHED_PASSWORD=${MEMCACHED_PASSWORD}/g" \
            /var/www/html/gallery/.env
    fi
    
    if [ -n ${RABBITMQ_HOST} ]; then

        RABBITMQ_VHOST_TAG=`echo ${RABBITMQ_VHOST} |sed  's|\/|\\\/|g'`

        sed -i \
            -e "s/RABBITMQ_HOST=/RABBITMQ_HOST=${RABBITMQ_HOST}/g" \
            -e "s/RABBITMQ_PORT=/RABBITMQ_PORT=${RABBITMQ_PORT}/g" \
            -e "s/RABBITMQ_VHOST=/RABBITMQ_VHOST=${RABBITMQ_VHOST_TAG}/g" \
            -e "s/RABBITMQ_LOGIN=/RABBITMQ_LOGIN=${RABBITMQ_LOGIN}/g" \
            -e "s/RABBITMQ_PASSWORD=/RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD}/g" \
            /var/www/html/gallery/.env
    fi
    
    if [ -n ${REDIS_HOST} ]; then
        sed -i \
            -e "s/REDIS_HOST=/REDIS_HOST=${REDIS_HOST}/g" \
            -e "s/REDIS_PORT=/REDIS_PORT=${REDIS_PORT}/g" \
            -e "s/REDIS_PASSWORD=/REDIS_PASSWORD=${REDIS_PASSWORD}/g" \
            /var/www/html/gallery/.env
    fi

    su -s /bin/bash - www-data -c "cd /var/www/html/gallery && php artisan migrate && \
        php artisan db:seed && php artisan route:cache"

    su -s /bin/bash - www-data -c "cd /var/www/html/gallery && php artisan queues enabled"

    if [ -n ${GALLERY_USER} ] || [ -n ${GALLERY_PASSWORD} ]; then
        su -s /bin/bash - www-data -c "cd /var/www/html/gallery && php artisan usermod admin@example.com --email=${GALLERY_USER} --password=${GALLERY_PASSWORD}"
    fi

    su -s /bin/bash - www-data -c "touch /var/www/html/install.lock"

fi

/usr/bin/supervisord -n -c /etc/supervisord.conf


exec "$@"
