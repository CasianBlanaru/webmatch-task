# WbmProductAttributes

Small Shopware 6 plugin for the hiring task.

The plugin lives in `custom/plugins/WbmProductAttributes`. I worked against the code in this repository, where `shopware/core` is pinned to `v6.7.10.1`. The task mentions 6.7.9.x, so the plugin constraint allows `~6.7.9 || ~6.7.10`.

## Setup

```bash
composer install
php bin/console plugin:refresh
php bin/console plugin:install --activate WbmProductAttributes
php bin/console database:migrate WbmProductAttributes --all
php bin/console cache:clear
bin/build-administration.sh
bin/build-storefront.sh
```

When Elasticsearch/OpenSearch is enabled, rebuild the product index after installing the plugin:

```bash
php bin/console es:index
```

In my local run the Docker database was exposed on a random host port, so I used `DATABASE_URL` per command instead of changing the project config. The local PHP memory limit was also too low for Shopware cache warmup, so I used `php -d memory_limit=-1` for console checks.

## Approach

I used Shopware custom fields, not a DAL `ProductEntity` extension.

For these two values that is the cleaner fit. Product custom fields are already shown in the Administration Specifications tab, are saved through the normal product API, and are part of Shopware's product search configuration. They are also known to the Elasticsearch product mapping when `include_in_search` is enabled.

A separate product extension table would make sense if these API attributes had their own lifecycle, needed relational constraints, or were queried heavily in custom SQL. For the task as given, it would add a lot of plumbing: extension definition, joins, Admin forms, indexing work, and extra persistence code.

The future note about 50+ API attributes is the main tradeoff. I would not blindly mirror all upstream fields into custom fields. I would keep the set curated. If those 50 fields became more like a structured API payload with reporting requirements, I would revisit the extension-table approach.

## Implemented

`productIdFromApi`

Integer custom field. It is attached to products and shown in the Specifications tab. The Admin field config sets it to disabled, so it is readonly in the product detail UI.

`productFormat`

Text custom field for the required string value. It is editable in the product detail Specifications tab and added as a column in `Catalogues > Products`.

The migration creates one custom field set, relates it to `product`, and upserts both fields. It also adds `customFields.productFormat` to every existing product search config with `searchable = 1`, `tokenize = 1`, and ranking `250`.

The storefront listing filter is registered through `ProductListingCollectFilterEvent`. It adds a `TermsAggregation` and, when values are selected, an `EqualsAnyFilter` on:

```text
product.customFields.productFormat
```

That keeps it inside Shopware's normal listing criteria flow. In OpenSearch mode, Shopware's criteria parser resolves the custom field path to the translated custom-field mapping.

The Twig part only renders the aggregation buckets using the existing `filter-multi-select` storefront plugin markup. No custom JavaScript was needed.

Search for values like `Bücher` should work after the plugin is installed and the ES index is rebuilt, because `productFormat` is added to the product search config.

## Verification

Static checks:

```bash
find custom/plugins/WbmProductAttributes -name '*.php' -print -exec php -l {} \;
composer validate custom/plugins/WbmProductAttributes/composer.json --strict
php -r '...json_decode snippet files with JSON_THROW_ON_ERROR...'
php -r '...DOMDocument load services.xml/phpunit.xml.dist...'
php -r '...MigrationStep::getPlausibleCreationTimestamp()...'
```

Shopware checks run locally:

```bash
php -d memory_limit=-1 bin/console plugin:refresh
php -d memory_limit=-1 bin/console plugin:install --activate WbmProductAttributes --no-interaction
php -d memory_limit=-1 bin/console lint:container
php -d memory_limit=-1 bin/console lint:twig custom/plugins/WbmProductAttributes/src/Resources/views
php -d memory_limit=-1 bin/console assets:install
```

I also checked the database after installation:

- both custom fields exist
- `productIdFromApi` has `disabled = true` in its config
- the field set is related to `product`
- `customFields.productFormat` exists in `product_search_config_field`
- the plugin is installed and active

The storefront filter contract was checked with a small PHP script against the real Shopware classes. It verifies that selected values like `Bücher|Hörbuch` become an `EqualsAnyFilter` on `product.customFields.productFormat`.

## Tests

The test scope is deliberately small. This is a timed task, and a big test suite here would be mostly noise.

The plugin contains PHPUnit tests for:

- the migration timestamp, because Shopware rejects timestamps outside the 32-bit range
- the storefront product format filter construction

The root project does not currently install PHPUnit. The plugin declares it as a dev dependency. To run the tests:

```bash
cd custom/plugins/WbmProductAttributes
composer install
../../../vendor/bin/phpunit -c phpunit.xml.dist
```

In a real project, the best next test would be an integration test that boots Shopware, installs the plugin, creates products with `productFormat`, indexes them, and checks the category listing filter. I did not add that here because it depends on a working database and OpenSearch setup and would take the task in the wrong direction.

## Still Open

I did not do a full browser walkthrough of the Administration and Storefront before writing this README. The backend installation and database state were verified, and the Administration/Storefront integration points were checked against the actual Shopware 6.7 source.

OpenSearch is present in the Docker setup, but the task already noted possible macOS image/storage issues. I kept the implementation ES-compatible and verified the mapping/search-config path, but I did not spend time debugging OpenSearch infrastructure.

## Tradeoffs

The product format filter uses the raw string as value and label. That is fine for `Bücher`, `DVD`, `Hörbuch`, etc. It also means inconsistent upstream spelling creates separate filter options.

`productIdFromApi` is readonly in the Admin UI, not at DAL write level. An API client with product write permissions can still change the custom field. If this value must be protected strictly, I would enforce that in the import process or add a write validator.

The custom-field approach keeps the plugin small. The cost is that too many API fields can make the custom-field set and ES mapping messy. That is why I would keep only business-relevant fields here.

## AI Usage

I used Cursor/ChatGPT for boilerplate and for checking Shopware details quickly. The useful part was looking up the actual 6.7 classes in this repository: the custom field renderer, product listing filters, and Elasticsearch criteria parser.

I reviewed the generated code manually and adjusted it where it did not fit the Shopware codebase.

One suggestion I rejected was building a full DAL product extension with a separate table. It would be defensible for a different data shape, but for this task it added more moving parts than value.

## Commit Suggestions

1. `Add WBM product custom fields`
2. `Add product format admin column`
3. `Add product format storefront listing filter`
4. `Add focused plugin tests`
5. `Document implementation decisions`
