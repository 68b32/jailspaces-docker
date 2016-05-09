#!/bin/bash
webspace_name="`basename \"$1\" | cut -d. -f1`"
echo "Username for webspace: $webspace_name"
/usr/local/sbin/js tls forcerefresh "$webspace_name"
