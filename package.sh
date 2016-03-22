#!/bin/bash

VERSION="3.0.0"

# OS X stupidity
export COPYFILE_DISABLE=true

# Store the script working directory
WD=$(pwd)

PACKAGE=bolt-${VERSION}
BUILD_DIR=$WD/build
COMPILE_DIR=$BUILD_DIR/compile
SHIPPING_DIR=$BUILD_DIR/${PACKAGE}
ARCHIVE_DIR=$WD/files

# Load any custom script if it exists
if [[ -f "$WD/custom.sh" ]] ; then
    source $WD/custom.sh
fi

# Set up fresh build directory
cd $WD
rm -rf $WD/build/

# Create a Composer project directory
composer create-project bolt/composer-install:^3.0 $COMPILE_DIR --prefer-dist --no-interaction -stability dev
if [ $? -ne 0 ] ; then
    echo "Composer did not complete successfully"
    exit 255
fi

# Copy in theme
rsync -a $COMPILE_DIR/vendor/bolt/bolt/theme/base-2014/ $COMPILE_DIR/public/theme/base-2014/
rsync -a $COMPILE_DIR/vendor/bolt/bolt/theme/base-2016/ $COMPILE_DIR/public/theme/base-2016/
rsync -a $COMPILE_DIR/vendor/bolt/bolt/files/ $COMPILE_DIR/public/files/

# Set file & directory permssions
find $COMPILE_DIR -type d -exec chmod 755 {} \;
find $COMPILE_DIR -type f -exec chmod 644 {} \;
find $COMPILE_DIR/vendor/bin/ -type l -exec chmod 755 {} \;
chmod 777 $COMPILE_DIR/public/files $COMPILE_DIR/app/cache $COMPILE_DIR/app/config $COMPILE_DIR/app/database
chmod +x $COMPILE_DIR/app/nut

# Add .htaccess file to vendor/
cp $WD/extras/.htaccess $COMPILE_DIR/vendor/.htaccess

# Remove ._ files
[[ -f "/usr/sbin/dot_clean" ]] && dot_clean $COMPILE_DIR/.

# Remove extra stuff that is not needed for average installs
rsync -a --delete --cvs-exclude --exclude-from=$WD/excluded.files $COMPILE_DIR/ $SHIPPING_DIR/

# Execute custom pre-archive event script
if [[ -f "$WD/custom.sh" ]] ; then
    custom_pre_archive
fi

# Make the archives
rm -f $ARCHIVE_DIR/*.tar.gz
rm -f $ARCHIVE_DIR/*.zip

cd $BUILD_DIR
tar -czf $ARCHIVE_DIR/$PACKAGE.tar.gz $PACKAGE/
zip -rq  $ARCHIVE_DIR/$PACKAGE.zip    $PACKAGE/
cd $WD

# Execute custom post-archive event script
if [[ -f "$WD/custom.sh" ]] ; then
    custom_post_archive
fi

echo 'All done!'
