#!/bin/sh

FILENAME="bolt_0.6.3"
export COPYFILE_DISABLE=true

cd bolt-git/
git pull
php composer.phar self-update
php composer.phar update
cd ..

rm -rf bolt
cp -rf bolt-git bolt
find bolt/vendor -name ".git" | xargs rm -rf
find bolt/vendor -name "tests" | xargs rm -rf
find bolt/vendor -name "Tests" | xargs rm -rf
rm -rf bolt/.git bolt/composer.* bolt/vendor/symfony/locale/Symfony/Component/Locale/Resources/data bolt/.gitignore
rm -rf bolt/app/view/img/debug-nipple-src.png bolt/app/view/img/*.pxm

# remove ._ files..
dot_clean .

# setting the correct filerights
find bolt -type d -exec chmod 755 {} \;
find bolt -type f -exec chmod 644 {} \;
chmod -R 777 bolt/files bolt/app/cache bolt/app/config bolt/app/database bolt/theme

# Make the archives..
tar -czf $FILENAME.tgz bolt
cp $FILENAME.tgz ./files/bolt_latest.tgz
mv $FILENAME.tgz ./files/

zip -rq $FILENAME.zip bolt
cp $FILENAME.zip ./files/bolt_latest.zip
mv $FILENAME.zip ./files/

echo "\nAll done!\n"
