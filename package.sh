#!/bin/bash

VERSION="2.0.5"

STABLE_VER="2.0.5"
STABLE_NAME=""
STABLE_FILE="bolt-$STABLE_VER"

DEV_VER="2.1.0"
DEV_NAME="alpha0"
DEV_FILE="bolt-$DEV_VER-$DEV_NAME"

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
git pull --all

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
[[ -d "$WD/files" ]] || mkdir $WD/files/
cp $TARGETDIR/app/config/config.yml.dist $WD/files/config.yml
cp $TARGETDIR/app/config/contenttypes.yml.dist $WD/files/contenttypes.yml
cp $TARGETDIR/app/config/menu.yml.dist $WD/files/menu.yml
cp $TARGETDIR/app/config/routing.yml.dist $WD/files/routing.yml
cp $TARGETDIR/app/config/taxonomy.yml.dist $WD/files/taxonomy.yml
cp $TARGETDIR/.htaccess $WD/files/default.htaccess

# setting the correct filerights
find $TARGETDIR -type d -exec chmod 755 {} \;
find $TARGETDIR -type f -exec chmod 644 {} \;
chmod -R 777 $TARGETDIR/files $TARGETDIR/app/cache $TARGETDIR/app/config $TARGETDIR/app/database $TARGETDIR/theme

# Fix in Symfony's form validator. See https://github.com/symfony/Form/commit/fb0765dd0317c75d1c023a654dc6d805e0d95b0d
# patch -p1 < patch/symfony-form-validator-2.5.3.patch

# Add .htaccess file to vendor/
cp $WD/extras/.htaccess $TARGETDIR/vendor/.htaccess

# Execute custom pre-archive event script
if [[ -f "$WD/custom.sh" ]] ; then
    custom_pre_archive
fi

# Make the archives..
tar -czf $WD/files/$FILENAME.tar.gz $TARGETDIR/
zip -rq  $WD/files/$FILENAME.zip    $TARGETDIR/

# Only create 'latest' archives for version releases
if [[ $1 = "" ]] ; then
    cp $WD/files/$FILENAME.tar.gz $WD/files/bolt-latest.tar.gz
    cp $WD/files/$FILENAME.zip    $WD/files/bolt-latest.zip
fi

# Create version.json
printf '{"stable":{"version":"%s","name":"%s","file":"%s"},"dev":{"version":"%s","name":"%s","file":"%s"}}' \
    "$STABLE_VER" "$STABLE_NAME" "$STABLE_FILE" "$DEV_VER" "$DEV_NAME" "$DEV_FILE" > $WD/files/version.json

# Execute custom post-archive event script
if [[ -f "$WD/custom.sh" ]] ; then
    custom_post_archive
fi

printf '\nAll done!\n'

# scp files/* bolt@bolt.cm:/home/bolt/public_html/distribution/
