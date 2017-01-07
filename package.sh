#!/usr/bin/env bash

# Note: OSX ships with an ancient version of rsync. If you build on that, you might
# need to upgrade rsync using brew, and set this OSX-specific path instead in your
# custom.sh script:
#
# RSYNC=/usr/local/bin/rsync

# Store the script working directory
WD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Include scripts
source $WD/include/parameters.sh
source $WD/include/functions.sh
# Load any custom script if it exists
if [[ -f "$WD/custom.sh" ]] ; then
    source $WD/custom.sh
fi

if [[ $1 = "" ]] ; then
    usage
fi

if [[ $MAJOR_VER < 2 ]] ; then
    usage
fi

# Set up fresh build directory
rm -rf $BUILD_DIR/
mkdir -p $BUILD_DIR

# Create a Composer project directory
echo "Creating Composer project for Bolt installation…"
composer_create_project $COMPOSER_INSTALL_REQUIRE $COMPILE_DIR

echo "    Setting project's Bolt version"
composer_require $BOLT_INSTALL_REQUIRE $COMPILE_DIR

# Store the installed Bolt version
get_bolt_version

# Set file & directory permissions
echo "    Setting file & directory permissions…"
set_filesystem_perms $COMPILE_DIR

# Set some configuration settings.
echo "    Updating debug settings in config.yml"
set_config_yml_debug $COMPILE_DIR

# Add .htaccess file to vendor/
cp $WD/extras/.htaccess $COMPILE_DIR/vendor/.htaccess

# Override .gitignore file with our copy
cp $WD/extras/.gitignore $COMPILE_DIR/.gitignore

# Remove ._ files
[[ -f "/usr/sbin/dot_clean" ]] && dot_clean $COMPILE_DIR/.

# Remove extra stuff that is not needed for average installs
create_clean_deployment $COMPILE_DIR/ $SHIPPING_DIR/

# Create a flat structure deployment
create_clean_deployment $COMPILE_DIR/ $SHIPPING_DIR-flat-structure/
flatten_project

# Don't overwrite user modified Composer files
composer_backup_files $SHIPPING_DIR
composer_backup_files $SHIPPING_DIR-flat-structure

# Execute custom pre-archive event script
if [[ -f "$WD/custom.sh" ]] ; then
    custom_pre_archive
fi

# Make the archives
rm -f $ARCHIVE_DIR/*.tar.gz
rm -f $ARCHIVE_DIR/*.zip

# Create the normal archive
create_archive $ARCHIVE_DIR/$PACKAGE $PACKAGE
# Create the flat webroot archive
create_archive $ARCHIVE_DIR/$PACKAGE-flat-structure $PACKAGE-flat-structure

# Copy current .yml.dist files
cp $BUILD_DIR/$PACKAGE/vendor/bolt/bolt/app/config/*yml.dist $ARCHIVE_DIR/

# Execute custom post-archive event script
if [[ -f "$WD/custom.sh" ]] ; then
    cd $WD
    custom_post_archive
fi

echo 'All done!'
