<?php declare(strict_types=1);

namespace Wbm\ProductAttributes\Migration;

use Doctrine\DBAL\Connection;
use Shopware\Core\Framework\Migration\MigrationStep;
use Shopware\Core\Framework\Uuid\Uuid;
use Wbm\ProductAttributes\AttributeNames;

class Migration1780000000ProductCustomFields extends MigrationStep
{
    private const FIELD_SET_ID = '018f0000000071209f0a000000000001';
    private const FIELD_SET_RELATION_ID = '018f0000000071209f0a000000000002';
    private const PRODUCT_ID_FIELD_ID = '018f0000000071209f0a000000000003';
    private const PRODUCT_FORMAT_FIELD_ID = '018f0000000071209f0a000000000004';

    public function getCreationTimestamp(): int
    {
        return 1780000000;
    }

    public function update(Connection $connection): void
    {
        $now = (new \DateTimeImmutable())->format('Y-m-d H:i:s.v');

        $connection->executeStatement(
            <<<'SQL'
INSERT INTO custom_field_set (id, name, config, active, created_at)
VALUES (:id, :name, :config, 1, :createdAt)
ON DUPLICATE KEY UPDATE
    config = VALUES(config),
    active = VALUES(active),
    updated_at = VALUES(created_at)
SQL,
            [
                'id' => Uuid::fromHexToBytes(self::FIELD_SET_ID),
                'name' => 'wbm_product_attributes',
                'config' => json_encode([
                    'label' => [
                        'en-GB' => 'WBM product attributes',
                        'de-DE' => 'WBM Produktattribute',
                    ],
                    'translated' => false,
                    'customFieldPosition' => 20,
                ], \JSON_THROW_ON_ERROR),
                'createdAt' => $now,
            ]
        );

        $connection->executeStatement(
            <<<'SQL'
INSERT INTO custom_field_set_relation (id, set_id, entity_name, created_at)
VALUES (:id, :setId, 'product', :createdAt)
ON DUPLICATE KEY UPDATE updated_at = VALUES(created_at)
SQL,
            [
                'id' => Uuid::fromHexToBytes(self::FIELD_SET_RELATION_ID),
                'setId' => Uuid::fromHexToBytes(self::FIELD_SET_ID),
                'createdAt' => $now,
            ]
        );

        $this->upsertCustomField(
            $connection,
            self::PRODUCT_ID_FIELD_ID,
            AttributeNames::PRODUCT_ID_FROM_API,
            'int',
            [
                'label' => [
                    'en-GB' => 'Product ID from API',
                    'de-DE' => 'Produkt-ID aus API',
                ],
                'helpText' => [
                    'en-GB' => 'Imported identifier from the external API.',
                    'de-DE' => 'Importierte Kennung aus der externen API.',
                ],
                'componentName' => 'sw-field',
                'type' => 'number',
                'numberType' => 'int',
                'disabled' => true,
                'customFieldPosition' => 1,
            ],
            false,
            $now
        );

        $this->upsertCustomField(
            $connection,
            self::PRODUCT_FORMAT_FIELD_ID,
            AttributeNames::PRODUCT_FORMAT,
            'text',
            [
                'label' => [
                    'en-GB' => 'Product format',
                    'de-DE' => 'Produktformat',
                ],
                'placeholder' => [
                    'en-GB' => 'e.g. Books',
                    'de-DE' => 'z. B. Bücher',
                ],
                'componentName' => 'sw-field',
                'type' => 'text',
                'customFieldPosition' => 2,
            ],
            true,
            $now
        );

        $this->addProductFormatToSearchConfig($connection, $now);
    }

    public function updateDestructive(Connection $connection): void
    {
    }

    /**
     * @param array<string, mixed> $config
     */
    private function upsertCustomField(
        Connection $connection,
        string $id,
        string $name,
        string $type,
        array $config,
        bool $includeInSearch,
        string $now
    ): void {
        $connection->executeStatement(
            <<<'SQL'
INSERT INTO custom_field (id, name, type, config, active, set_id, include_in_search, created_at)
VALUES (:id, :name, :type, :config, 1, :setId, :includeInSearch, :createdAt)
ON DUPLICATE KEY UPDATE
    type = VALUES(type),
    config = VALUES(config),
    active = VALUES(active),
    set_id = VALUES(set_id),
    include_in_search = VALUES(include_in_search),
    updated_at = VALUES(created_at)
SQL,
            [
                'id' => Uuid::fromHexToBytes($id),
                'name' => $name,
                'type' => $type,
                'config' => json_encode($config, \JSON_THROW_ON_ERROR),
                'setId' => Uuid::fromHexToBytes(self::FIELD_SET_ID),
                'includeInSearch' => $includeInSearch ? 1 : 0,
                'createdAt' => $now,
            ]
        );
    }

    private function addProductFormatToSearchConfig(Connection $connection, string $now): void
    {
        $searchConfigIds = $connection->fetchFirstColumn('SELECT id FROM product_search_config');

        foreach ($searchConfigIds as $searchConfigId) {
            $connection->executeStatement(
                <<<'SQL'
INSERT INTO product_search_config_field
    (id, product_search_config_id, custom_field_id, field, tokenize, searchable, ranking, created_at)
VALUES
    (:id, :searchConfigId, :customFieldId, :field, 1, 1, 250, :createdAt)
ON DUPLICATE KEY UPDATE
    custom_field_id = VALUES(custom_field_id),
    tokenize = VALUES(tokenize),
    searchable = VALUES(searchable),
    ranking = VALUES(ranking),
    updated_at = VALUES(created_at)
SQL,
                [
                    'id' => random_bytes(16),
                    'searchConfigId' => $searchConfigId,
                    'customFieldId' => Uuid::fromHexToBytes(self::PRODUCT_FORMAT_FIELD_ID),
                    'field' => 'customFields.' . AttributeNames::PRODUCT_FORMAT,
                    'createdAt' => $now,
                ]
            );
        }
    }
}
