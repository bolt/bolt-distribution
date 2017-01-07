#!/bin/bash

# OS X stupidity
export COPYFILE_DISABLE=true

function usage () {
    echo "ERROR: Bolt's Composer version constraint is required, with optional stability."
    echo "Usage:"
    echo "    $BASH_SOURCE [ -s dev|beta|rc ] x.y[.z]"
    echo ""
    echo "Usage examples:"
    echo "    $BASH_SOURCE 3.2"
    echo "    $BASH_SOURCE -s beta 3.3"
    echo "    $BASH_SOURCE -s dev 3.4"
    echo ""

    exit 1
}

if [[ $1 = "" ]] ; then
    usage
fi

# Store the script working directory
WD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source parameters
source $WD/parameters

if [[ $MAJOR_VER < 2 ]] ; then
    echo $MAJOR_VER
    exit 1
    usage
fi

# Load any custom script if it exists
if [[ -f "$WD/custom.sh" ]] ; then
    source $WD/custom.sh
fi

# Set up fresh build directory
cd $WD
rm -rf $WD/build/

# Create a Composer project directory
echo "Creating Composer project for Bolt installation…"
composer create-project bolt/composer-install:$COMPOSER_INSTALL_REQUIRE \
    $COMPILE_DIR \
    --no-dev \
    --no-scripts \
    --prefer-dist \
    --no-interaction \
    --stability beta \
    --ignore-platform-reqs

if [ $? -ne 0 ] ; then
    echo "Composer did not complete successfully"
    exit 255
fi

echo "Setting project's Bolt version"
composer require bolt/bolt:$BOLT_INSTALL_REQUIRE \
    passwordlib/passwordlib:^1.0@beta \
    bolt/configuration-notices:^1.0@dev \
    --working-dir=$COMPILE_DIR \
    --ignore-platform-reqs \
    --no-interaction

if [ $? -ne 0 ] ; then
    echo "Composer did not complete successfully"
    exit 255
fi

# Store the installed Bolt version
get_bolt_version

# Set file & directory permissions
find $COMPILE_DIR -type d -exec chmod 755 {} \;
find $COMPILE_DIR -type f -exec chmod 644 {} \;
find $COMPILE_DIR/vendor/bin/ -type l -exec chmod 755 {} \;
chmod 777 $COMPILE_DIR/public/files $COMPILE_DIR/app/cache $COMPILE_DIR/app/config $COMPILE_DIR/app/database
chmod +x $COMPILE_DIR/app/nut

# Set some configuration settings.
perl -p -i -e 's/\#strict_variables: false/strict_variables: false/' $COMPILE_DIR/vendor/bolt/bolt/app/config/config.yml.dist
perl -p -i -e 's/\#production_error_level: 8181/production_error_level: 8181/' $COMPILE_DIR/vendor/bolt/bolt/app/config/config.yml.dist
perl -p -i -e 's/\# debug_error_level: 8181/debug_error_level: 8181/' $COMPILE_DIR/vendor/bolt/bolt/app/config/config.yml.dist
perl -p -i -e 's/debug_error_level: -1/# debug_error_level: -1/' $COMPILE_DIR/vendor/bolt/bolt/app/config/config.yml.dist

# Add .htaccess file to vendor/
cp $WD/extras/.htaccess $COMPILE_DIR/vendor/.htaccess

# Override .gitignore file with our copy
cp $WD/extras/.gitignore $COMPILE_DIR/.gitignore

# Remove ._ files
[[ -f "/usr/sbin/dot_clean" ]] && dot_clean $COMPILE_DIR/.

# Remove extra stuff that is not needed for average installs
rsync -a --delete --cvs-exclude --include=app/cache/.gitignore --exclude-from=$WD/excluded.files $COMPILE_DIR/ $SHIPPING_DIR/

# Note: OSX ships with an ancient version of rsync. If you build on that, you might
# need to upgrade rsync using brew, and use this OSX-specific path instead:
# /usr/local/bin/rsync

# Don't overwrite user modified Composer files
mv $SHIPPING_DIR/composer.json $SHIPPING_DIR/composer.json.dist
mv $SHIPPING_DIR/composer.lock $SHIPPING_DIR/composer.lock.dist

# Execute custom pre-archive event script
if [[ -f "$WD/custom.sh" ]] ; then
    custom_pre_archive
fi

# Make the archives
rm -f $ARCHIVE_DIR/*.tar.gz
rm -f $ARCHIVE_DIR/*.zip

cd $BUILD_DIR

cp $PACKAGE/vendor/bolt/bolt/app/config/*yml.dist $ARCHIVE_DIR/
tar -czf $ARCHIVE_DIR/$PACKAGE.tar.gz $PACKAGE/
zip -rq --symlinks $ARCHIVE_DIR/$PACKAGE.zip $PACKAGE/
cd $WD

# Execute custom post-archive event script
if [[ -f "$WD/custom.sh" ]] ; then
    custom_post_archive
fi

echo 'All done!'
