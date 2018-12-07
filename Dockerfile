FROM php:7.2-fpm-alpine as base

ARG project_root=.

# install git for computing diffs
RUN apk add --update git

# install Composer
COPY ${project_root}/docker-install-composer /usr/local/bin/docker-install-composer
RUN chmod +x /usr/local/bin/docker-install-composer && docker-install-composer

# libpng-dev needed by "gd" extension
# icu-dev needed by "intl" extension
# postgresql-dev needed by "pgsql" extension
# libzip-dev needed by "zip" extension
# autoconf needed by "redis" extension
# freetype-dev needed by "gd" extension
# libjpeg-turbo-dev needed by "gd" extension
RUN apk add --update \
    libpng-dev \
    icu-dev \
    postgresql-dev \
    libzip-dev \
    autoconf \
    freetype-dev \
    libjpeg-turbo-dev

# "zip" extension warns about deprecation if we do not use a system library
RUN docker-php-ext-configure zip --with-libzip

# "gd" extension needs to have specified jpeg and freetype dir for jpg/jpeg images support
RUN docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/

# install necessary PHP extensions requested by Composer
RUN docker-php-ext-install \
    bcmath \
    gd \
    intl \
    opcache \
    pgsql \
    pdo_pgsql \
    zip

# redis PHP extension is not provided with the PHP source and must be installed via PECL, build-base used only for installation
RUN apk add --update build-base && pecl install redis-4.0.2 && docker-php-ext-enable redis && apk del build-base

# install npm
RUN apk add --update nodejs-npm

# install grunt-cli using npm to be able to run grunt watch
RUN npm install -g grunt-cli

# install postgresql to allow execution of pg_dump for acceptance tests
RUN apk add --update --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/v3.7/main postgresql

# install locales and switch to en_US.utf8 in order to enable UTF-8 support
# see https://github.com/docker-library/php/issues/240#issuecomment-305038173
RUN apk add --update --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing gnu-libiconv
ENV LD_PRELOAD /usr/lib/preloadable_libiconv.so php
ENV LC_ALL=en_US.utf8 LANG=en_US.utf8 LANGUAGE=en_US.utf8

# overwrite the original entry-point from the PHP Docker image with our own
COPY ${project_root}/docker-php-entrypoint /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-php-entrypoint

# copy php.ini configuration
COPY ${project_root}/php-ini-overrides.ini /usr/local/etc/php/php.ini

# the user "www-data" is used when running the image, and therefore should own the workdir
RUN chown www-data:www-data /var/www/html
USER www-data

# hirak/prestissimo makes the install of Composer dependencies faster by parallel downloading
RUN composer global require hirak/prestissimo

# set COMPOSER_MEMORY_LIMIT to -1 (i.e. unlimited - this is a hotfix until https://github.com/shopsys/shopsys/issues/634 is solved)
ENV COMPOSER_MEMORY_LIMIT=-1
