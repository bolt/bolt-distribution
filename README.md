bolt-distribution
=================

Some simple scripts to package the Bolt distribution files. 

Custom Event Script
-------------------

You can add a file called `custom.sh` that defines two functions that will be called just before the archive is made
and again after it is complete.

The basic layout example of `custom.sh`: 

```bash
#!/bin/sh

function custom_pre_archive {
    echo "Pre archive function"
}

function custom_post_archive {
    echo "Post archive function"
}
```