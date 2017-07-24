#!/usr/bin/env bash

# Calculated parameters
BUILD_DIR=$WD/build
COMPILE_DIR=$BUILD_DIR/compile
ARCHIVE_DIR=$WD/files
DATA_FILE=$BUILD_DIR/.data
PROD_TARGET="bolt@bolt.cm:/var/www/sites/bolt.cm/distribution/"
STABILITY="stable"
COMPOSER_INSTALL_VER=3.2
PHP_TOO_HIGH_VER=5.6
PHP=$(which php)
RSYNC=$(which rsync)
AWK=$(which gawk)
LINK="$(which ln) -s"

# Set variables base on passed options
OPTIND=1
while getopts "s:p:" OPTION ; do
    case "$OPTION" in
        p)
            COMPOSER_INSTALL_VER="$OPTARG"
            ;;
        s)
            STABILITY="$OPTARG"
            ;;
        *)
            echo "$OPTION"
            usage
            ;;
    esac
done

shift $(($OPTIND - 1))
BASE_BOLT_VER="$1"
MAJOR_VER=$($AWK -v RS=[0-9]+ '{print RT+0;exit}' <<< "$BASE_BOLT_VER")
MAJOR_MINOR_VER=$($AWK -v RS=[0-9]+\.[0-9]+ '{print RT+0;exit}' <<< "$BASE_BOLT_VER")

if [[ $COMPOSER_INSTALL_VER == "" ]] ; then
    COMPOSER_INSTALL_VER="^$MAJOR_MINOR_VER"
    BOLT_INSTALL_REQUIRE="^$MAJOR_MINOR_VER"
elif [[ $STABILITY == "stable" ]] ; then
    COMPOSER_INSTALL_REQUIRE="^$MAJOR_MINOR_VER"
    BOLT_INSTALL_REQUIRE="^${BASE_BOLT_VER}"
elif [[ $STABILITY == "beta" ]] ; then
    COMPOSER_INSTALL_REQUIRE="^$MAJOR_MINOR_VER"
    BOLT_INSTALL_REQUIRE="^${BASE_BOLT_VER}@beta"
else
    COMPOSER_INSTALL_REQUIRE="^${COMPOSER_INSTALL_VER}@${STABILITY}"
    BOLT_INSTALL_REQUIRE="${MAJOR_MINOR_VER}.x-dev@${STABILITY}"
fi

if [[ $RSYNC == "" ]] ; then
    echo "Couldn't find rsync in path."
    echo ""
    exit 1
fi

# OS X stupidity
export COPYFILE_DISABLE=true
