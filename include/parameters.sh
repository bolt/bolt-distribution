#!/usr/bin/env bash

# Calculated parameters
BUILD_DIR=$WD/build
COMPILE_DIR=$BUILD_DIR/compile
ARCHIVE_DIR=$WD/files
STABILITY="stable"
COMPOSER_INSTALL_VER=3.2
RSYNC=$(which rsync)

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
MAJOR_VER=$(awk -v RS=[0-9]+ '{print RT+0;exit}' <<< "$BASE_BOLT_VER")
MAJOR_MINOR_VER=$(awk -v RS=[0-9]+\.[0-9]+ '{print RT+0;exit}' <<< "$BASE_BOLT_VER")

if [[ $COMPOSER_INSTALL_VER == "" ]] ; then
    COMPOSER_INSTALL_VER="^$MAJOR_MINOR_VER"
    BOLT_INSTALL_REQUIRE="^$MAJOR_MINOR_VER"
fi

if [[ $STABILITY == "stable" ]] ; then
    COMPOSER_INSTALL_REQUIRE="^$BASE_BOLT_VER"
else
    COMPOSER_INSTALL_REQUIRE="^${COMPOSER_INSTALL_VER}@${STABILITY}"
    BOLT_INSTALL_REQUIRE="^${BASE_BOLT_VER}@${STABILITY}"
fi

if [[ $RSYNC == "" ]] ; then
    echo "Couldn't find rsync in path."
    echo ""
    exit 1
fi

# OS X stupidity
export COPYFILE_DISABLE=true
