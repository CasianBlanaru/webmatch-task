FROM dunglas/frankenphp:1-php8.4

ENV APP_ENV=prod
ENV SHOPWARE_SKIP_WEBINSTALLER=1

WORKDIR /app

RUN apt-get update && apt-get install -y \
    git \
    unzip \
    curl \
    zip \
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

RUN a2dismod mpm_prefork mpm_worker mpm_event || true

COPY . .
COPY Caddyfile /etc/caddy/Caddyfile

RUN composer install \
    --no-dev \
    --prefer-dist \
    --optimize-autoloader

RUN mkdir -p \
    var/cache \
    var/log \
    public/media \
    public/thumbnail \
    public/bundles \
    public/theme \
    && chown -R www-data:www-data var public

EXPOSE 8080

CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]