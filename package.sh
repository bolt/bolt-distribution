#!/bin/bash

VERSION="2.3.0-alpha4"

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
ROOT_BUILD=$WD/build

# Set our git repo directory
ROOT_GIT=$WD/bolt-git

# Set our archive directory
ROOT_ARCHIVE=$WD/files

# Load any custom script if it exists
if [[ -f "$WD/custom.sh" ]] ; then
    source $WD/custom.sh
fi

# Do a full pull on our git repo
cd $ROOT_GIT
git reset --hard HEAD
git checkout master
git fetch --all
git reset --hard origin/master

# If no parameter is passed to the script package the tagged version
if [[ $1 = "" ]] ; then
    echo Doing checkout of version tagged: v$VERSION
    git checkout -q v$VERSION
    FILENAME="bolt-$VERSION"
    DISTDIR="bolt-$VERSION"
else
    # If the parameter 'master' is passed, we already have it, else a commit ID
    # shall be checked out
    if [[ $1 != "master" ]] ; then
        git checkout $1
    fi
    COD=$(git log -1 --date=short --format=%cd)
    GID=$(git log -1 --format=%h)
    FILENAME="bolt-git-$COD-$GID"
    DISTDIR="bolt-git-$COD-$GID"
fi

# Update Composer itself and any required packages
[[ -f 'composer.lock' ]] && rm composer.lock
php composer.phar self-update
php composer.phar require --no-update guzzle/guzzle ~3.9
php composer.phar update --no-dev --optimize-autoloader

rm -rf $ROOT_ARCHIVE/*
rm -rf $ROOT_BUILD
mkdir -p $ROOT_BUILD/$DISTDIR

# Remove extra stuff that is not needed for average installs
rsync -a --delete --cvs-exclude --exclude-from=$WD/excluded.files $ROOT_GIT/ $ROOT_BUILD/$DISTDIR

cp $ROOT_GIT/composer.json $ROOT_BUILD/$DISTDIR/composer.json.dist
cp $ROOT_GIT/composer.lock $ROOT_BUILD/$DISTDIR/composer.lock.dist

# Remove ._ files
[[ -f "/usr/sbin/dot_clean" ]] && dot_clean $ROOT_BUILD/$DISTDIR/.

# Copy the default config files
[[ -d "$ROOT_ARCHIVE" ]] || mkdir $ROOT_ARCHIVE/
cp $ROOT_GIT/app/config/config.yml.dist       $ROOT_ARCHIVE/config.yml
cp $ROOT_GIT/app/config/contenttypes.yml.dist $ROOT_ARCHIVE/contenttypes.yml
cp $ROOT_GIT/app/config/menu.yml.dist         $ROOT_ARCHIVE/menu.yml
cp $ROOT_GIT/app/config/routing.yml.dist      $ROOT_ARCHIVE/routing.yml
cp $ROOT_GIT/app/config/taxonomy.yml.dist     $ROOT_ARCHIVE/taxonomy.yml
cp $ROOT_GIT/.htaccess $ROOT_ARCHIVE/default.htaccess

# setting the correct file rights
find $ROOT_BUILD/$DISTDIR -type d -exec chmod 755 {} \;
find $ROOT_BUILD/$DISTDIR -type f -exec chmod 644 {} \;
chmod -R 777 $ROOT_BUILD/$DISTDIR/files $ROOT_BUILD/$DISTDIR/app/cache $ROOT_BUILD/$DISTDIR/app/config $ROOT_BUILD/$DISTDIR/app/database $ROOT_BUILD/$DISTDIR/theme

cd $ROOT_BUILD/$DISTDIR
# Fix in Symfony's form validator. See https://github.com/symfony/Form/commit/fb0765dd0317c75d1c023a654dc6d805e0d95b0d
# patch -p1 < patch/symfony-form-validator-2.5.3.patch

# PHP 5.3 compatibility for Guzzle
patch -p1 < $WD/patch/reactphp-promise-php-5.3.diff

# Add .htaccess file to vendor/
cp $WD/extras/.htaccess $ROOT_BUILD/$DISTDIR/vendor/.htaccess

# Execute custom pre-archive event script
if [[ -f "$WD/custom.sh" ]] ; then
    custom_pre_archive
fi

# Make the archives
cd $ROOT_BUILD
tar -czf $ROOT_ARCHIVE/$FILENAME.tar.gz $DISTDIR/
zip -rq  $ROOT_ARCHIVE/$FILENAME.zip    $DISTDIR/

# Only create 'latest' archives for version releases
if [[ $1 = "" ]] ; then
    cp $ROOT_ARCHIVE/$FILENAME.tar.gz $ROOT_ARCHIVE/bolt-latest.tar.gz
    cp $ROOT_ARCHIVE/$FILENAME.zip    $ROOT_ARCHIVE/bolt-latest.zip
fi

# Create version.json
printf '{"stable":{"version":"%s","name":"%s","file":"%s"},"dev":{"version":"%s","name":"%s","file":"%s"}}' \
    "$STABLE_VER" "$STABLE_NAME" "$STABLE_FILE" "$DEV_VER" "$DEV_NAME" "$DEV_FILE" > $ROOT_ARCHIVE/version.json

# Execute custom post-archive event script
if [[ -f "$WD/custom.sh" ]] ; then
    custom_post_archive
fi

printf 'All done!'

# scp files/* bolt@bolt.cm:/home/bolt/public_html/distribution/
