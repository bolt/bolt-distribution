#!/usr/bin/env bash

# Store the script working directory
WD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SOURCE=$BASH_SOURCE

function bad_setup () {
    echo ""
    echo "[FAILED] This script requires a valid custom.sh file to be configured."
    echo ""
    exit 1
}

function bad_data_source () {
    echo ""
    echo "[FAILED] Build data file missing or corrupt!"
    echo ""
    exit 1
}

# Include scripts
source $WD/include/parameters.sh
source $WD/include/functions.sh
[[ ! -f "$WD/custom.sh" ]] && bad_setup
source $WD/custom.sh
source $DATA_FILE
[[ ! -f "$DATA_FILE" ]] && bad_data_source

[[ $BUILD_MAJOR_MINOR_VER == "" ]] && bad_data_source
[[ $BUILD_PACKAGE == "" ]] && bad_data_source
[[ $BUILD_STABILITY == "" ]] && bad_data_source
[[ $PROD_TARGET == "" ]] && bad_data_source

# Upload archive files
DST="$PROD_TARGET/archive/$BUILD_MAJOR_MINOR_VER" ; [[ "$DST" =~ /$ ]] || DST="$DST/"
$RSYNC -av $ARCHIVE_DIR/$BUILD_PACKAGE.tar.gz \
    $ARCHIVE_DIR/$BUILD_PACKAGE.zip \
    $ARCHIVE_DIR/$BUILD_PACKAGE-flat-structure.tar.gz \
    $ARCHIVE_DIR/$BUILD_PACKAGE-flat-structure.zip \
    "$DST"

# If not publishing a stable release, skip symlinks
if [[ $BUILD_STABILITY != "stable" ]] ; then
    echo "Skiping symlinks for stability of \"$BUILD_STABILITY\""
    exit 0
fi

# Remove old symlinks
find $ARCHIVE_DIR -type l -print0 | xargs -0 rm -f

# Create new symlinks
pushd $ARCHIVE_DIR
$LINK archive/$BUILD_MAJOR_MINOR_VER/$BUILD_PACKAGE.tar.gz                bolt-latest.tar.gz
$LINK archive/$BUILD_MAJOR_MINOR_VER/$BUILD_PACKAGE.zip                   bolt-latest.zip
$LINK archive/$BUILD_MAJOR_MINOR_VER/$BUILD_PACKAGE-flat-structure.tar.gz bolt-latest-flat-structure.tar.gz
$LINK archive/$BUILD_MAJOR_MINOR_VER/$BUILD_PACKAGE-flat-structure.zip    bolt-latest-flat-structure.zip

# Push symlinks
DST="$PROD_TARGET" ; [[ "$DST" =~ /$ ]] || DST="$DST/"
$RSYNC -av --links \
    bolt-latest.tar.gz \
    bolt-latest.zip \
    bolt-latest-flat-structure.tar.gz \
    bolt-latest-flat-structure.zip \
    $PROD_TARGET
