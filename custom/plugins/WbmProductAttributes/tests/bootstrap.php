<?php declare(strict_types=1);

use Composer\Autoload\ClassLoader;

$loader = require __DIR__ . '/../../../../vendor/autoload.php';
\assert($loader instanceof ClassLoader);

$loader->addPsr4('Wbm\\ProductAttributes\\', __DIR__ . '/../src');
$loader->addPsr4('Wbm\\ProductAttributes\\Tests\\', __DIR__);
