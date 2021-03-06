FROM php:7.4-fpm-buster as base

ARG project_root=.

# install required tools
# git for computing diffs
# wget for installation of other tools
# gnupg and g++ for gd extension
# locales for locale-gen command
# apt-utils so package configuartion does not get delayed
# unzip to ommit composer zip packages corruption
# dialog for apt-get to be
# git for computing diffs and for npm to download packages
RUN apt-get update && apt-get install -y wget gnupg g++ locales unzip dialog apt-utils git && apt-get clean

# Install NodeJS
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash
RUN apt-get update && apt-get install -y nodejs && apt-get clean

# install Composer
COPY ./docker-install-composer /usr/local/bin/docker-install-composer

RUN chmod +x /usr/local/bin/docker-install-composer && \
    docker-install-composer

# libpng-dev needed by "gd" extension
# libzip-dev needed by "zip" extension
# libicu-dev for intl extension
# libpg-dev for connection to postgres database
# autoconf needed by "redis" extension
RUN apt-get update && \
    apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    libpq-dev \
    vim \
    nano \
    mc \
    htop \
    autoconf && \
    apt-get clean

# "gd" extension needs to have specified jpeg and freetype dir for jpg/jpeg images support
RUN docker-php-ext-configure gd --with-freetype --with-jpeg

# install necessary tools for running application
RUN docker-php-ext-install \
    bcmath \
    calendar \
    fileinfo \
    gd \
    intl \
    opcache \
    pgsql \
    pdo_pgsql \
    zip

# install PostgreSQl client for dumping database
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -sc)-pgdg main" > /etc/apt/sources.list.d/PostgreSQL.list' && \
    apt-get update && apt-get install -y postgresql-12 postgresql-client-12 && apt-get clean

# install redis extension
RUN pecl install redis-5.2.1 && \
    docker-php-ext-enable redis

# install locales and switch to en_US.utf8 in order to enable UTF-8 support
# see http://jaredmarkell.com/docker-and-locales/ from where was this code taken
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# copy php.ini configuration
COPY ./php-ini-overrides.ini /usr/local/etc/php/php.ini

# overwrite the original entry-point from the PHP Docker image with our own
COPY ./docker-php-entrypoint /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-php-entrypoint

# set www-data user his home directory
# the user "www-data" is used when running the image, and therefore should own the workdir
RUN usermod -m -d /home/www-data www-data && \
    mkdir -p /var/www/html && \
    chown -R www-data:www-data /home/www-data /var/www/html

# Switch to user
USER www-data

RUN mkdir /home/www-data/.npm-global
ENV NPM_CONFIG_PREFIX /home/www-data/.npm-global

# hirak/prestissimo makes the install of Composer dependencies faster by parallel downloading
RUN composer global require hirak/prestissimo

# set COMPOSER_MEMORY_LIMIT to -1 (i.e. unlimited - this is a hotfix until https://github.com/shopsys/shopsys/issues/634 is solved)
ENV COMPOSER_MEMORY_LIMIT=-1
