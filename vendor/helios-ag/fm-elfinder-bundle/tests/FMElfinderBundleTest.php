<?php

namespace FM\ElfinderBundle\Tests;

use FM\ElfinderBundle\FMElfinderBundle;
use Symfony\Component\DependencyInjection\ContainerBuilder;
use Symfony\Component\HttpKernel\Bundle\Bundle;

class FMElfinderBundleTest extends \PHPUnit\Framework\TestCase
{
    public function testBundle(): void
    {
        $bundle = new FMElfinderBundle();
        $this->assertInstanceOf(Bundle::class, $bundle);
    }

}
