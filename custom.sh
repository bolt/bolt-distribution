#!/bin/sh

# An example custom script that is not over written by git pull
#
# Use this script to add pre/post archive creation tasks such as additional
# patches, or copying the archive to a desired location.

function custom_pre_archive {
    echo "Doing pre-archive tasks..."
}

function custom_post_archive {
    echo "Doing post-archive tasks..."
}
