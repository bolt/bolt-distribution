#!/usr/bin/env bash

function usage () {
    echo "ERROR: Bolt's Composer version constraint is required, with optional stability."
    echo "Usage:"
    echo "    $SOURCE [ -s dev|beta|rc ] x.y[.z]"
    echo ""
    echo "Usage examples:"
    echo "    $SOURCE 3.2"
    echo "    $SOURCE -s beta 3.3"
    echo "    $SOURCE -s dev 3.4"
    echo ""

    exit 1
}

function get_bolt_version () {
    pushd $BUILD_DIR

    PACKAGE=bolt-$(composer --working-dir=$COMPILE_DIR show | grep bolt/bolt | awk '{print $2}')
    SHIPPING_DIR=$BUILD_DIR/${PACKAGE}

    popd
}

# Create zip & tar archives
#
# $1 — Prefix (with path) of the resulting file(s)
# $2 — Source files to be archived
function create_archive () {
    pushd $BUILD_DIR

    _PREFIX=$1
    _SOURCE=$2

    tar -czf $_PREFIX.tar.gz $_SOURCE/
    zip -rq --symlinks $_PREFIX.zip $_SOURCE/

    popd
}

# Create the initial Composer project
#
# $1 — The constraint to pass to Composer for "bolt/composer-install"
# $2 — Project directory
function composer_create_project () {
    pushd $BUILD_DIR

    _REQUIRE=$1
    _PROJECT_DIR=$2

    composer create-project bolt/composer-install:$_REQUIRE \
        $_PROJECT_DIR \
        --no-dev \
        --no-scripts \
        --prefer-dist \
        --no-interaction \
        --stability beta \
        --ignore-platform-reqs \
        --no-install

    if [ $? -ne 0 ] ; then
        echo "Composer did not complete successfully"
        exit 255
    fi

    popd
}

# Require specific Bolt version & packages
#
# $1 — The constraint to pass to Composer for "bolt/bolt"
# $2 — Project directory
function composer_require () {
    pushd $BUILD_DIR

    _REQUIRE=$1
    _PROJECT_DIR=$2
    _PACKAGES="passwordlib/passwordlib:^1.0@beta"

    if [[ $MAJOR_MINOR_VER -gt 3.2 ]] ; then
        $_PACKAGES = "$_PACKAGES bolt/configuration-notices:^1.0@dev"
    fi

    composer require bolt/bolt:$_REQUIRE \
        $_PACKAGES \
        --working-dir=$_PROJECT_DIR \
        --ignore-platform-reqs \
        --no-interaction \
        --no-suggest \
        --no-scripts

    if [ $? -ne 0 ] ; then
        echo "Composer did not complete successfully"
        exit 255
    fi

    popd
}

# Remove packages
#
# $1 — Project directory
function composer_remove () {
    pushd $BUILD_DIR

    _PROJECT_DIR=$1

#    composer remove
#        --working-dir=$_PROJECT_DIR \
#        --no-interaction

    if [ $? -ne 0 ] ; then
        echo "Composer did not complete successfully"
        exit 255
    fi

    popd
}

function composer_scripts_create_project () {
    pushd $BUILD_DIR

    _PROJECT_DIR=$1

    composer run-script  \
        --working-dir=$_PROJECT_DIR \
        --no-interaction \
        post-create-project-cmd

    if [ $? -ne 0 ] ; then
        echo "Composer did not complete successfully"
        exit 255
    fi

    popd
}

# Move JSON & lock files to .dist
#
# $1 —
function composer_backup_files () {
    _PROJECT_DIR=$1

    mv $_PROJECT_DIR/composer.json $_PROJECT_DIR/composer.json.dist
    mv $_PROJECT_DIR/composer.lock $_PROJECT_DIR/composer.lock.dist
}

# Set require permissions
#
# $1 — Target directory
function set_filesystem_perms () {
    _COMPILE_DIR=$1

    find $_COMPILE_DIR -type d -exec chmod 755 {} \;
    find $_COMPILE_DIR -type f -exec chmod 644 {} \;
    find $_COMPILE_DIR/vendor/bin/ -type l -exec chmod 755 {} \;
    chmod 777 $_COMPILE_DIR/public/files $_COMPILE_DIR/app/cache $_COMPILE_DIR/app/config $_COMPILE_DIR/app/database
    chmod +x $_COMPILE_DIR/app/nut
}

# Set debug settings in config.yml
#
# $1 — Target directory
function set_config_yml_debug () {
    _COMPILE_DIR=$1

    perl -p -i -e 's/\#strict_variables: false/strict_variables: false/' $_COMPILE_DIR/vendor/bolt/bolt/app/config/config.yml.dist
    perl -p -i -e 's/\#production_error_level: 8181/production_error_level: 8181/' $_COMPILE_DIR/vendor/bolt/bolt/app/config/config.yml.dist
    perl -p -i -e 's/\# debug_error_level: 8181/debug_error_level: 8181/' $_COMPILE_DIR/vendor/bolt/bolt/app/config/config.yml.dist
    perl -p -i -e 's/debug_error_level: -1/# debug_error_level: -1/' $_COMPILE_DIR/vendor/bolt/bolt/app/config/config.yml.dist
}

# Create a clean directory install to be archived
#
# $1 — Source directory
# $2 — Target directory
function create_clean_deployment () {
    SRC=$1
    DST=$2

    $RSYNC -a --delete --cvs-exclude --include=app/cache/.gitignore --exclude-from=$WD/excluded.files $SRC/ $DST/
}

# Flatten the structure of the project
function flatten_project () {
    FLAT_DIR=$SHIPPING_DIR-flat-structure
    pushd $FLAT_DIR

    mv $FLAT_DIR/public/* $FLAT_DIR/public/.htaccess $FLAT_DIR/
    rm -rf $FLAT_DIR/public

    perl -p -i -e 's/ public\// /g' $FLAT_DIR/.bolt.yml
    perl -p -i -e 's/ public/ ./g' $FLAT_DIR/.bolt.yml

    popd
}

function banner_start () {
    echo "Setting up the following:"
    echo "    Base Bolt version: $BASE_BOLT_VER"
    echo "    Major version number: $MAJOR_VER"
    echo "    Major & minor version number: $MAJOR_MINOR_VER"
    echo "    Require for project install: $COMPOSER_INSTALL_REQUIRE"
    echo "    Require for Bolt install: $BOLT_INSTALL_REQUIRE"
    echo ""
}
