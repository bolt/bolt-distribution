#!/bin/sh

git clone git://github.com/bobdenotter/bolt.git bolt-git
cd bolt-git/
curl -s http://getcomposer.org/installer | php
php composer.phar install
cd ..

echo "\nCloned Bolt, downloaded components!\n"
