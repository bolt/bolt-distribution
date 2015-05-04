#!/bin/bash

VERSION="2.1.0"

STABLE_VER="2.1.0"
STABLE_NAME=""
STABLE_FILE="bolt-$STABLE_VER"

DEV_VER="2.2.0"
DEV_NAME="alpha0"
DEV_FILE="bolt-$DEV_VER-$DEV_NAME"

export COPYFILE_DISABLE=true

# Store the script working directory
WD=$(pwd)

# Set our build directory
BUILDDIR=$WD/build

# Set our git repo directory
GITDIR=$WD/bolt-git

# Set our archive directory
ARCHIVEDIR=$WD/files

# Load any custom script if it exists
if [[ -f "$WD/custom.sh" ]] ; then
    source $WD/custom.sh
fi

# Do a full pull on our git repo
cd $GITDIR
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

# Update Composer iteslf and any required packages
php composer.phar self-update
php composer.phar require --no-update guzzle/guzzle ~3.9
php composer.phar update --no-dev --optimize-autoloader

rm -rf $BUILDDIR
mkdir  -p $BUILDDIR
cp -rf $GITDIR/ $BUILDDIR/$TARGETDIR/

rm -rf $ARCHIVEDIR/*

# Remove extra stuff that is not needed for average installs
cd $BUILDDIR
find $TARGETDIR -name ".git*" | xargs rm -rf
find $TARGETDIR -type d -name "[tT]ests" | xargs rm -rf
rm -rf $TARGETDIR/app/database/.gitignore \
       $TARGETDIR/app/src/ \
       $TARGETDIR/app/view/img/debug-nipple-src.png \
       $TARGETDIR/app/view/lib \
       $TARGETDIR/app/view/sass \
       $TARGETDIR/app/view/src \
       $TARGETDIR/codeception.yml \
       $TARGETDIR/composer.phar \
       $TARGETDIR/contributing.md \
       $TARGETDIR/phpunit.xml.dist \
       $TARGETDIR/run-functional-tests \
       $TARGETDIR/tests/ \
       $TARGETDIR/theme/base-2013/to_be_deleted \
       $TARGETDIR/theme/base-2014/bower.json \
       $TARGETDIR/theme/base-2014/Gruntfile.js \
       $TARGETDIR/theme/base-2014/package.json \
       $TARGETDIR/theme/default \
       $TARGETDIR/vendor/psr/log/Psr/Log/Test \
       $TARGETDIR/vendor/swiftmailer/swiftmailer/doc \
       $TARGETDIR/vendor/swiftmailer/swiftmailer/notes \
       $TARGETDIR/vendor/swiftmailer/swiftmailer/test-suite \
       $TARGETDIR/vendor/symfony/form/Symfony/Component/Form/Test \
       $TARGETDIR/vendor/symfony/locale/Symfony/Component/Locale/Resources/data \
       $TARGETDIR/vendor/twig/twig/lib/Twig/Test \
       $TARGETDIR/vendor/twig/twig/test \
       $TARGETDIR/.gitignore \
       $TARGETDIR/.scrutinizer.yml \
       $TARGETDIR/.travis.*

mv $TARGETDIR/composer.json $TARGETDIR/composer.json.dist
mv $TARGETDIR/composer.lock $TARGETDIR/composer.lock.dist

# Remove ._ files
cd $BUILDDIR
[[ -f "/usr/sbin/dot_clean" ]] && dot_clean $TARGETDIR/.

# Copy the default config files
cd $BUILDDIR
[[ -d "$ARCHIVEDIR" ]] || mkdir $ARCHIVEDIR/
cp $TARGETDIR/app/config/config.yml.dist $ARCHIVEDIR/config.yml
cp $TARGETDIR/app/config/contenttypes.yml.dist $ARCHIVEDIR/contenttypes.yml
cp $TARGETDIR/app/config/menu.yml.dist $ARCHIVEDIR/menu.yml
cp $TARGETDIR/app/config/routing.yml.dist $ARCHIVEDIR/routing.yml
cp $TARGETDIR/app/config/taxonomy.yml.dist $ARCHIVEDIR/taxonomy.yml
cp $TARGETDIR/.htaccess $ARCHIVEDIR/default.htaccess

# setting the correct file rights
cd $BUILDDIR
find $TARGETDIR -type d -exec chmod 755 {} \;
find $TARGETDIR -type f -exec chmod 644 {} \;
chmod -R 777 $TARGETDIR/files $TARGETDIR/app/cache $TARGETDIR/app/config $TARGETDIR/app/database $TARGETDIR/theme

# Fix in Symfony's form validator. See https://github.com/symfony/Form/commit/fb0765dd0317c75d1c023a654dc6d805e0d95b0d
# patch -p1 < patch/symfony-form-validator-2.5.3.patch

# Add .htaccess file to vendor/
cd $BUILDDIR
cp $WD/extras/.htaccess $TARGETDIR/vendor/.htaccess

# Execute custom pre-archive event script
if [[ -f "$WD/custom.sh" ]] ; then
    custom_pre_archive
fi

# Make the archives
cd $BUILDDIR
tar -czf $ARCHIVEDIR/$FILENAME.tar.gz $TARGETDIR/
zip -rq  $ARCHIVEDIR/$FILENAME.zip    $TARGETDIR/

# Only create 'latest' archives for version releases
if [[ $1 = "" ]] ; then
    cp $ARCHIVEDIR/$FILENAME.tar.gz $ARCHIVEDIR/bolt-latest.tar.gz
    cp $ARCHIVEDIR/$FILENAME.zip    $ARCHIVEDIR/bolt-latest.zip
fi

# Create version.json
printf '{"stable":{"version":"%s","name":"%s","file":"%s"},"dev":{"version":"%s","name":"%s","file":"%s"}}' \
    "$STABLE_VER" "$STABLE_NAME" "$STABLE_FILE" "$DEV_VER" "$DEV_NAME" "$DEV_FILE" > $ARCHIVEDIR/version.json

# Execute custom post-archive event script
if [[ -f "$WD/custom.sh" ]] ; then
    custom_post_archive
fi

printf '\nAll done!\n'

# scp files/* bolt@bolt.cm:/home/bolt/public_html/distribution/
