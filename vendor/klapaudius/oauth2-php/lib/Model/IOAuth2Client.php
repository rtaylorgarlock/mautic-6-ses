<?php

namespace OAuth2\Model;

use Symfony\Component\Security\Core\User\UserInterface;

interface IOAuth2Client extends UserInterface
{
    /**
     * @return string
     */
    public function getPublicId();

    /**
     * @return array
     */
    public function getRedirectUris();
}
