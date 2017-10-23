FROM php:7.1-cli

LABEL maintainer="Ruzhentsev Alexandr <git@pgallery.ru>"
LABEL version="1.0 beta"
LABEL description="PHP-CLI image for pGallery workers"

RUN apt-get update && apt-get -y upgrade && apt-get install -y git libpng12-dev libjpeg-dev libsqlite3-dev \
        libicu-dev libmemcached-dev libxml2-dev libxslt1-dev libcurl4-gnutls-dev libbz2-dev libzip-dev \
        libmcrypt-dev libtidy-dev libmagick++-dev libssh-dev librabbitmq-dev \
    && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr \
    && pecl install imagick amqp

RUN docker-php-ext-install \
        bcmath bz2 calendar curl dom fileinfo gd \
        gettext gettext iconv intl json \
        mcrypt mysqli opcache pdo pdo_mysql phar \
        soap tidy xml xmlrpc xsl zip

RUN git clone https://github.com/php-memcached-dev/php-memcached memcached \
    && ( \
        cd memcached && git checkout php7 && phpize \
        && ./configure --with-php-config=/usr/local/bin/php-config \
        && make && make install \
    ) \
    && rm -r memcached

RUN git clone https://github.com/phpredis/phpredis.git \
    && ( \
        cd phpredis && phpize \
        && ./configure \
        && make -j$(nproc) && make install \
    ) \
    && rm -r phpredis

RUN docker-php-ext-enable redis memcached imagick amqp \
    && apt-get purge --auto-remove -y gcc make \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

RUN php -r "readfile('https://getcomposer.org/installer');" > composer-setup.php \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && php -r "unlink('composer-setup.php');"

RUN rm -rf /usr/src/php.tar.xz

COPY config/php.ini 		/usr/local/etc/php/
COPY config/opcache.ini 	/usr/local/etc/php/conf.d/docker-php-ext-opcache.ini
COPY scripts/ 			/usr/local/bin/

RUN chmod 755 /usr/local/bin/docker-entrypoint.sh

VOLUME /var/www/html

EXPOSE 9000

CMD ["/usr/local/bin/docker-entrypoint.sh"]
