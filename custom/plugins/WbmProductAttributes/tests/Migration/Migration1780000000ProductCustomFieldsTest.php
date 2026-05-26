<?php declare(strict_types=1);

namespace Wbm\ProductAttributes\Tests\Migration;

use PHPUnit\Framework\TestCase;
use Wbm\ProductAttributes\Migration\Migration1780000000ProductCustomFields;

class Migration1780000000ProductCustomFieldsTest extends TestCase
{
    public function testMigrationTimestampIsAcceptedByShopware(): void
    {
        $migration = new Migration1780000000ProductCustomFields();

        static::assertSame(1780000000, $migration->getPlausibleCreationTimestamp());
    }
}
