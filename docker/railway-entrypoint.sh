#!/usr/bin/env sh

set -eu

cd /app

mkdir -p var/log
touch var/log/prod.log
tail -n 0 -F var/log/*.log &

wait_for_database() {
    if [ -z "${DATABASE_URL:-}" ]; then
        echo "DATABASE_URL is not set"
        return 1
    fi

    case "$DATABASE_URL" in
        *'${{'*|*'}}'*)
            echo "DATABASE_URL still contains an unresolved Railway variable reference"
            return 1
            ;;
    esac

    php <<'PHP'
<?php
$url = getenv('DATABASE_URL');
$parts = parse_url($url);
$host = $parts['host'] ?? '';
$port = (int) ($parts['port'] ?? 3306);

if ($host === '') {
    fwrite(STDERR, "DATABASE_URL does not contain a database host\n");
    exit(1);
}

fwrite(STDOUT, sprintf("Checking database %s:%d\n", $host, $port));

for ($attempt = 1; $attempt <= 60; ++$attempt) {
    $socket = @fsockopen($host, $port, $errno, $errstr, 2.0);

    if ($socket !== false) {
        fclose($socket);
        fwrite(STDOUT, "Database is reachable\n");
        exit(0);
    }

    fwrite(STDOUT, sprintf("Waiting for database %s:%d (%d/60)\n", $host, $port, $attempt));
    sleep(2);
}

fwrite(STDERR, "Database did not become reachable\n");
exit(1);
PHP
}

initialize_shopware() {
    wait_for_database || return 1

    if php -d memory_limit=-1 bin/console system:is-installed --quiet; then
        echo "Shopware is already installed"
    else
        echo "Installing Shopware"
        php -d memory_limit=-1 bin/console system:install \
            --force \
            --basic-setup \
            --skip-assets-install \
            --skip-first-run-wizard \
            --shop-name="${SHOPWARE_SHOP_NAME:-Webmatch Task}" \
            --shop-email="${SHOPWARE_SHOP_EMAIL:-admin@example.com}" \
            --shop-locale="${SHOPWARE_SHOP_LOCALE:-de-DE}" \
            --shop-currency="${SHOPWARE_SHOP_CURRENCY:-EUR}" \
            --no-interaction
    fi

    php -d memory_limit=-1 bin/console database:migrate --all --no-interaction
    php -d memory_limit=-1 bin/console plugin:refresh --no-interaction
    php -d memory_limit=-1 bin/console plugin:install --activate WbmProductAttributes --no-interaction \
        || php -d memory_limit=-1 bin/console plugin:activate WbmProductAttributes --no-interaction \
        || true
    php -d memory_limit=-1 bin/console database:migrate WbmProductAttributes --all --no-interaction || true
    php -d memory_limit=-1 bin/console cache:clear --no-interaction || true
}

initialize_shopware &

exec frankenphp run --config /etc/caddy/Caddyfile
