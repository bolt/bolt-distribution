#!/bin/bash

VERSION="2.0.0-beta"

export COPYFILE_DISABLE=true

# Store the script working directory
WD=$(pwd)

# Load any custom script if it exists
if [[ -f "$WD/custom.sh" ]] ; then
    source $WD/custom.sh
fi

cd bolt-git/
[[ -f 'composer.lock' ]] && rm composer.lock
git checkout master
git pull

# If no parameter is passed to the script package the tagged version
if [[ $1 = "" ]] ; then
    echo Doing checkout of version tagged: v$VERSION
    git checkout -q v$VERSION
    FILENAME="bolt-$VERSION"
    TARGETDIR="bolt-$VERSION"
else
    # If the parameter 'master' is passed, we already have it, else a commit ID
    # shall be checked out
    if [[ $1 != "master" ]] ; then
        git checkout $1
    fi
    COD=$(git log -1 --date=short --format=%cd)
    GID=$(git log -1 --format=%h)
    FILENAME="bolt-git-$COD-$GID"
    TARGETDIR="bolt-git-$COD-$GID"
fi

php composer.phar self-update
php composer.phar update --no-dev --optimize-autoloader
cd ..

rm -rf build
mkdir  build/
cp -rf bolt-git build/$TARGETDIR

rm -rf files/*

cd build/
find $TARGETDIR -name ".git*" | xargs rm -rf
find $TARGETDIR -type d -name "[tT]ests" | xargs rm -rf
rm -rf $TARGETDIR/vendor/psr/log/Psr/Log/Test $TARGETDIR/vendor/symfony/form/Symfony/Component/Form/Test $TARGETDIR/vendor/twig/twig/lib/Twig/Test
rm -rf $TARGETDIR/vendor/twig/twig/test $TARGETDIR/vendor/swiftmailer/swiftmailer/test-suite
rm -rf $TARGETDIR/composer.* $TARGETDIR/vendor/symfony/locale/Symfony/Component/Locale/Resources/data $TARGETDIR/.gitignore $TARGETDIR/app/database/.gitignore
rm -rf $TARGETDIR/app/view/img/debug-nipple-src.png $TARGETDIR/app/view/img/*.pxm
rm -rf $TARGETDIR/vendor/swiftmailer/swiftmailer/doc $TARGETDIR/vendor/swiftmailer/swiftmailer/notes
rm -rf $TARGETDIR/theme/default $TARGETDIR/theme/base-2013/to_be_deleted
rm -rf $TARGETDIR/.scrutinizer.yml $TARGETDIR/.travis.yml $TARGETDIR/codeception.yml $TARGETDIR/run-functional-tests
rm -f  $TARGETDIR/theme/base-2014/Gruntfile.js $TARGETDIR/theme/base-2014/package.json $TARGETDIR/theme/base-2014/bower.json
rm -rf $TARGETDIR/CodeSniffer/
rm -rf $TARGETDIR/test/
rm -rf $TARGETDIR/tests/
rm -f  $TARGETDIR/phpunit.xml.dist

# remove ._ files..
[[ -f "/usr/sbin/dot_clean" ]] && dot_clean $TARGETDIR/.

# copy the default config files.
[[ -d "../files" ]] || mkdir ../files/
cp $TARGETDIR/app/config/config.yml.dist ../files/config.yml
cp $TARGETDIR/app/config/contenttypes.yml.dist ../files/contenttypes.yml
cp $TARGETDIR/app/config/menu.yml.dist ../files/menu.yml
cp $TARGETDIR/app/config/routing.yml.dist ../files/routing.yml
cp $TARGETDIR/app/config/taxonomy.yml.dist ../files/taxonomy.yml
cp $TARGETDIR/.htaccess ../files/default.htaccess

# setting the correct filerights
find $TARGETDIR -type d -exec chmod 755 {} \;
find $TARGETDIR -type f -exec chmod 644 {} \;
chmod -R 777 $TARGETDIR/files $TARGETDIR/app/cache $TARGETDIR/app/config $TARGETDIR/app/database $TARGETDIR/theme

# Fix in Symfony's form validator. See https://github.com/symfony/Form/commit/fb0765dd0317c75d1c023a654dc6d805e0d95b0d
# patch -p1 < patch/symfony-form-validator-2.5.3.patch

# Add .htaccess file to vendor/
cp ../extras/.htaccess $TARGETDIR/vendor/.htaccess

# Execute custom pre-archive event script
if [[ -f "$WD/custom.sh" ]] ; then
    custom_pre_archive
fi

# Make the archives..
tar -czf ../files/$FILENAME.tar.gz $TARGETDIR/
zip -rq  ../files/$FILENAME.zip    $TARGETDIR/

# Only create 'latest' archives for version releases
if [[ $1 = "" ]] ; then
    cp ../files/$FILENAME.tar.gz ../files/bolt-latest.tar.gz
    cp ../files/$FILENAME.zip    ../files/bolt-latest.zip
fi

# Execute custom post-archive event script
if [[ -f "$WD/custom.sh" ]] ; then
    custom_post_archive
fi

echo "\nAll done!\n"

# scp files/* bolt@bolt.cm:/home/bolt/public_html/distribution/
