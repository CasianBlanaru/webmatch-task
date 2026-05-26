FROM php:8.4-apache

ARG COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_ALLOW_SUPERUSER=${COMPOSER_ALLOW_SUPERUSER}
ENV APP_ENV=prod
ENV SHOPWARE_SKIP_WEBINSTALLER=1
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

WORKDIR /var/www/html

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        acl \
        bash \
        curl \
        git \
        gnupg \
        libfreetype6-dev \
        libicu-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libzip-dev \
        unzip \
        zip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j"$(nproc)" gd intl opcache pdo_mysql zip \
    && a2enmod rewrite headers \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && corepack enable \
    && rm -rf /var/lib/apt/lists/*

COPY . .

RUN composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader \
    && if [ -f bin/build-administration.sh ]; then bash bin/build-administration.sh; fi \
    && if [ -f bin/build-storefront.sh ]; then bash bin/build-storefront.sh; fi \
    && mkdir -p var/cache var/log public/media public/thumbnail public/bundles public/theme \
    && chown -R www-data:www-data var public

COPY docker/start.sh /usr/local/bin/shopware-start
RUN chmod +x /usr/local/bin/shopware-start

EXPOSE 8080

CMD ["shopware-start"]
