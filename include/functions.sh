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
    pushd $BUILD_DIR > /dev/null

    PACKAGE=bolt-$($PHP $COMPOSER --working-dir=$COMPILE_DIR show | grep bolt/bolt | awk '{print $2}')
    SHIPPING_DIR=$BUILD_DIR/${PACKAGE}

    popd > /dev/null
}

# Create zip & tar archives
#
# $1 — Prefix (with path) of the resulting file(s)
# $2 — Source files to be archived
function create_archive () {
    pushd $BUILD_DIR > /dev/null

    _PREFIX=$1
    _SOURCE=$2

    tar -czf $_PREFIX.tar.gz $_SOURCE/
    zip -rq --symlinks $_PREFIX.zip $_SOURCE/

    popd > /dev/null
}

# Create the initial Composer project
#
# $1 — The constraint to pass to Composer for "bolt/composer-install"
# $2 — Project directory
function composer_create_project () {
    pushd $BUILD_DIR > /dev/null

    _REQUIRE=$1
    _PROJECT_DIR=$2

    $PHP $COMPOSER create-project bolt/composer-install:$_REQUIRE \
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

    popd > /dev/null
}

# Require specific Bolt version & packages
#
# $1 — The constraint to pass to Composer for "bolt/bolt"
# $2 — Project directory
function composer_require () {
    pushd $BUILD_DIR > /dev/null

    _REQUIRE=$1
    _PROJECT_DIR=$2
    _PACKAGES="passwordlib/passwordlib:^1.0@beta"

    if (( $(echo "$MAJOR_MINOR_VER > 3.2" | bc -l) )); then
        _PACKAGES="$_PACKAGES bolt/configuration-notices:^1.0"
    fi

    if (( $(echo "$MAJOR_MINOR_VER > 3.3" | bc -l) )); then
        _PACKAGES="$_PACKAGES bolt/simple-deploy:^1.0@beta"
    fi

    $PHP $COMPOSER require bolt/bolt:$_REQUIRE \
        $_PACKAGES \
        --working-dir=$_PROJECT_DIR \
        --no-interaction \
        --no-suggest \
        --no-scripts

    if [ $? -ne 0 ] ; then
        echo "Composer did not complete successfully"
        exit 255
    fi

    popd > /dev/null
}

# Require deployed specific Bolt version & packages
#
# $1 — The constraint to pass to Composer for "bolt/bolt"
# $2 — Project directory
function composer_require_set () {
    pushd $BUILD_DIR > /dev/null

    _PROJECT_DIR=$1

    $PHP $COMPOSER require bolt/bolt:$BOLT_INSTALL_REQUIRE \
        --working-dir=$_PROJECT_DIR \
        --no-interaction \
        --no-suggest \
        --no-scripts \
        --no-update

    if [ $? -ne 0 ] ; then
        echo "Composer did not complete successfully"
        exit 255
    fi

    popd > /dev/null
}

# Remove packages
#
# $1 — Project directory
function composer_remove () {
    pushd $BUILD_DIR > /dev/null

    _PROJECT_DIR=$1

#    $PHP $COMPOSER remove
#        --working-dir=$_PROJECT_DIR \
#        --no-interaction

    if [ $? -ne 0 ] ; then
        echo "Composer did not complete successfully"
        exit 255
    fi

    popd > /dev/null
}

function composer_scripts_create_project () {
    pushd $BUILD_DIR > /dev/null

    _PROJECT_DIR=$1

    $PHP $COMPOSER run-script  \
        --working-dir=$_PROJECT_DIR \
        --no-interaction \
        post-create-project-cmd

    if [ $? -ne 0 ] ; then
        echo "Composer did not complete successfully"
        exit 255
    fi
    if (( $(echo "$MAJOR_MINOR_VER > 3.2" | bc -l) )); then
        if [ -f "$_PROJECT_DIR/.bolt.yml" ] ; then
            rm -rf $_PROJECT_DIR/.bolt.yml
        fi
    fi

    popd > /dev/null
}

# Create .dist files where required
#
# $1 — Target directory
function create_dist_files () {
    _PROJECT_DIR=$1

    echo ""
    echo "Creating .dist files"
    for file in composer.json composer.lock src/Site/CustomisationExtension.php ; do
        if [ -f $_PROJECT_DIR/$file ] ; then
            echo "    $file -> $file.dist"
            mv $_PROJECT_DIR/$file $_PROJECT_DIR/$file.dist
        else
            echo "    Skipping $file as it does not exist"
        fi
    done
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
    pushd $FLAT_DIR > /dev/null

    mv $FLAT_DIR/public/* $FLAT_DIR/public/.htaccess $FLAT_DIR/
    rm -rf $FLAT_DIR/public

    if [ -f "$FLAT_DIR/vendor/bolt/bolt/.bolt.yml" ] ; then
        cp $WD/extras/bolt.yml $FLAT_DIR/.bolt.yml
    else
        cp $WD/extras/v3.2.bolt.yml $FLAT_DIR/.bolt.yml
    fi
    perl -p -i -e 's/\.\.\/vendor/vendor/g' $FLAT_DIR/index.php

    popd > /dev/null
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

# Write out a source file containing build data variables to be used for
# pushing to live,
function write_build_data() {
    echo "#!/usr/bin/env bash" > $DATA_FILE
    echo "" >> $DATA_FILE
    echo "BUILD_MAJOR_VER=$MAJOR_VER" >> $DATA_FILE
    echo "BUILD_MAJOR_MINOR_VER=$MAJOR_MINOR_VER" >> $DATA_FILE
    echo "BUILD_STABILITY=$STABILITY" >> $DATA_FILE
    echo "BUILD_PACKAGE=$PACKAGE" >> $DATA_FILE
    echo "BUILD_PACKAGE_FLAT=$PACKAGE-flat-structure" >> $DATA_FILE
}

function check_php_version() {
    echo "Checking $PHP version"
    PHP_RUN_VER=$($PHP -r "echo version_compare(PHP_VERSION, '"$PHP_TOO_HIGH_VER"', '>=');")
    if [[ $PHP_RUN_VER != '' ]]; then
        echo "This must be run with PHP < $PHP_TOO_HIGH_VER"
        exit 1
    fi
}
