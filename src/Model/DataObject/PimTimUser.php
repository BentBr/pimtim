<?php

namespace App\Model\DataObject;

use Pimcore\Model\DataObject\PimTimUser as PimcoreUser;

/**
 * @method static PimTimUser\Listing getList(array $config = [])
 * @method static PimTimUser\Listing|PimTimUser|null getByPimcoreUsername($value, $limit = 0, $offset = 0, $objectTypes = null)
 */
class PimTimUser extends PimcoreUser
{

}
