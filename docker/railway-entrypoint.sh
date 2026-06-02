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

configure_sales_channel_domain() {
    if [ -z "${APP_URL:-}" ]; then
        echo "APP_URL is not set; skipping sales channel domain configuration"
        return 0
    fi

    php <<'PHP'
<?php
$appUrl = rtrim((string) getenv('APP_URL'), '/');
$appParts = parse_url($appUrl);

if (!isset($appParts['scheme'], $appParts['host'])) {
    fwrite(STDERR, "APP_URL must include a scheme and host, for example https://example.com\n");
    exit(1);
}

$dsn = (string) getenv('DATABASE_URL');
$dbParts = parse_url($dsn);

if (!isset($dbParts['scheme'], $dbParts['host'], $dbParts['path'])) {
    fwrite(STDERR, "DATABASE_URL is not parseable\n");
    exit(1);
}

$driver = str_starts_with($dbParts['scheme'], 'mysql') || str_starts_with($dbParts['scheme'], 'mariadb') ? 'mysql' : $dbParts['scheme'];
$database = ltrim($dbParts['path'], '/');
$port = (int) ($dbParts['port'] ?? 3306);
$user = rawurldecode((string) ($dbParts['user'] ?? ''));
$pass = rawurldecode((string) ($dbParts['pass'] ?? ''));

$pdo = new PDO(
    sprintf('%s:host=%s;port=%d;dbname=%s;charset=utf8mb4', $driver, $dbParts['host'], $port, $database),
    $user,
    $pass,
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);

$domains = $pdo->query("
    SELECT LOWER(HEX(sales_channel_domain.id)) AS id, sales_channel_domain.url
    FROM sales_channel_domain
    INNER JOIN sales_channel ON sales_channel.id = sales_channel_domain.sales_channel_id
    INNER JOIN sales_channel_type ON sales_channel_type.id = sales_channel.type_id
    WHERE sales_channel_type.icon_name = 'regular-storefront'
      AND sales_channel_domain.url NOT LIKE '%default.headless%'
    ORDER BY sales_channel_domain.url
")->fetchAll(PDO::FETCH_ASSOC);
$existingUrls = array_column($domains, 'url');

foreach ($domains as $domain) {
    $parts = parse_url($domain['url']);

    if ($parts === false) {
        continue;
    }

    $path = $parts['path'] ?? '';
    $query = isset($parts['query']) ? '?' . $parts['query'] : '';
    $fragment = isset($parts['fragment']) ? '#' . $parts['fragment'] : '';
    $port = isset($appParts['port']) ? ':' . $appParts['port'] : '';
    $newUrl = $appParts['scheme'] . '://' . $appParts['host'] . $port . $path . $query . $fragment;

    if ($newUrl === $domain['url']) {
        continue;
    }

    if (in_array($newUrl, $existingUrls, true)) {
        fwrite(STDOUT, sprintf("Sales channel domain %s already exists; keeping %s\n", $newUrl, $domain['url']));
        continue;
    }

    $statement = $pdo->prepare('UPDATE sales_channel_domain SET url = :url WHERE id = UNHEX(:id)');
    $statement->execute([
        'url' => $newUrl,
        'id' => $domain['id'],
    ]);
    $existingUrls[] = $newUrl;

    fwrite(STDOUT, sprintf("Updated sales channel domain %s to %s\n", $domain['url'], $newUrl));
}
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
    configure_sales_channel_domain
    php -d memory_limit=-1 bin/console plugin:refresh --no-interaction
    php -d memory_limit=-1 bin/console plugin:install --activate WbmProductAttributes --no-interaction \
        || php -d memory_limit=-1 bin/console plugin:activate WbmProductAttributes --no-interaction \
        || true
    php -d memory_limit=-1 bin/console database:migrate WbmProductAttributes --all --no-interaction || true

    # Remove compiled administration bundles to force rebuild with correct URLs
    rm -rf /app/public/bundles/administration || true

    # Rebuild assets and themes with correct HTTPS URLs
    php -d memory_limit=-1 bin/console assets:install --no-interaction || true
    php -d memory_limit=-1 bin/console theme:compile --no-interaction || true

    php -d memory_limit=-1 bin/console cache:clear --no-interaction || true
    php -d memory_limit=-1 bin/console assets:install --no-interaction || true
    php -d memory_limit=-1 bin/console theme:compile --no-interaction || true
}

initialize_shopware &

exec frankenphp run --config /etc/caddy/Caddyfile
