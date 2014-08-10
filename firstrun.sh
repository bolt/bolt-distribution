#!/bin/sh

git clone git://github.com/bolt/bolt.git bolt-git
cd bolt-git/
curl -s http://getcomposer.org/installer | php
php composer.phar install --no-dev
cd ..

echo "\nCloned Bolt, downloaded components!\n"
