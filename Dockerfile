# Stage 1: Shared PHP runtime with required Shopware extensions
FROM dunglas/frankenphp:1-php8.4 AS base

ENV APP_ENV=prod
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_NO_INTERACTION=1
ENV SHOPWARE_SKIP_WEBINSTALLER=1

WORKDIR /app

RUN apt-get update && apt-get install -y \
    git \
    unzip \
    curl \
    zip \
    jq \
    libicu-dev \
    libzip-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libwebp-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install \
        pdo_mysql \
        intl \
        zip \
        gd \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY --from=node:20-bookworm-slim /usr/local/bin/node /usr/local/bin/node
COPY --from=node:20-bookworm-slim /usr/local/bin/npm /usr/local/bin/npm
COPY --from=node:20-bookworm-slim /usr/local/bin/npx /usr/local/bin/npx
COPY --from=node:20-bookworm-slim /usr/local/lib/node_modules /usr/local/lib/node_modules

RUN a2dismod mpm_prefork mpm_worker mpm_event || true

# Stage 2: Install Composer dependencies with the same PHP extensions as runtime
FROM base AS vendor

COPY composer.json composer.lock ./
COPY custom/ custom/

RUN composer install \
    --no-dev \
    --no-scripts \
    --prefer-dist \
    --optimize-autoloader \
    && test -f vendor/autoload_runtime.php

# Stage 3: Build the final FrankenPHP image
FROM base AS app

COPY . .
COPY --from=vendor /app/vendor ./vendor
COPY Caddyfile /etc/caddy/Caddyfile
COPY docker/railway-entrypoint.sh /usr/local/bin/railway-entrypoint

RUN composer install \
    --no-dev \
    --no-scripts \
    --prefer-dist \
    --optimize-autoloader \
    && test -f vendor/autoload_runtime.php

RUN php -d memory_limit=-1 bin/console assets:install

RUN mkdir -p \
    var/cache \
    var/log \
    public/media \
    public/thumbnail \
    public/bundles \
    public/theme \
    && chown -R www-data:www-data var public

RUN chmod +x /usr/local/bin/railway-entrypoint

EXPOSE 8080

CMD ["railway-entrypoint"]
