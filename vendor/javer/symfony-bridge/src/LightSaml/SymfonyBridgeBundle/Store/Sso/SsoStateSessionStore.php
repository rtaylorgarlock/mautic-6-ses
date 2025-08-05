<?php

namespace LightSaml\SymfonyBridgeBundle\Store\Sso;

use LightSaml\State\Sso\SsoState;
use LightSaml\Store\Sso\SsoStateStoreInterface;
use Symfony\Component\HttpFoundation\RequestStack;
use Symfony\Component\HttpFoundation\Session\SessionInterface;

class SsoStateSessionStore implements SsoStateStoreInterface
{
    public function __construct(
        protected RequestStack $requestStack,
        protected string $key,
    )
    {
    }

    public function get(): SsoState
    {
        $result = $this->getSession()->get($this->key);

        if ($result === null) {
            $result = new SsoState();
            $this->set($result);
        }

        return $result;
    }

    public function set(SsoState $ssoState): void
    {
        $ssoState->setLocalSessionId($this->getSession()->getId());

        $this->getSession()->set($this->key, $ssoState);
    }

    protected function getSession(): SessionInterface
    {
        return $this->requestStack->getSession();
    }
}
