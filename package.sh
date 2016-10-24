#!/bin/bash

VERSION="3.2.0-rc1"

if [[ $1 = "" ]] ; then
    echo "ERROR: A Composer version constraint is required."
    echo ""
    echo "Usage examples:"
    echo "    $BASH_SOURCE ^3.1"
    echo "    $BASH_SOURCE ^3.2@beta"
    echo "    $BASH_SOURCE 3.3.x-dev"
    echo ""

    exit 1
fi

# OS X stupidity
export COPYFILE_DISABLE=true

# Store the script working directory
WD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source parameters
source $WD/parameters

# Load any custom script if it exists
if [[ -f "$WD/custom.sh" ]] ; then
    source $WD/custom.sh
fi

# Set up fresh build directory
cd $WD
rm -rf $WD/build/

# Create a Composer project directory
composer create-project bolt/composer-install:$CONSTRAINT $COMPILE_DIR --prefer-dist  --stability dev --no-dev --ignore-platform-reqs --no-interaction
if [ $? -ne 0 ] ; then
    echo "Composer did not complete successfully"
    exit 255
fi

if [ $DEBUG = true ] ; then
    composer require bolt/bolt:3.0.x-dev --working-dir=$COMPILE_DIR
    if [ $? -ne 0 ] ; then
        echo "Composer did not complete successfully"
        exit 255
    fi
fi

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
perl -p -i -e 's/\debug_error_level: -1/# debug_error_level: 8181/' $COMPILE_DIR/vendor/bolt/bolt/app/config/config.yml.dist

# Add .htaccess file to vendor/
cp $WD/extras/.htaccess $COMPILE_DIR/vendor/.htaccess

# Override .gitignore file with our copy
cp $WD/extras/.gitignore $COMPILE_DIR/.gitignore

# Remove ._ files
[[ -f "/usr/sbin/dot_clean" ]] && dot_clean $COMPILE_DIR/.

# Remove extra stuff that is not needed for average installs
# Note: OSX-specific path, because OSX installs an ancient version or rsync
/usr/local/bin/rsync -a --delete --cvs-exclude --include=app/cache/.gitignore --exclude-from=$WD/excluded.files $COMPILE_DIR/ $SHIPPING_DIR/

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
