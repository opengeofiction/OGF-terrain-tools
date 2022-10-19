#! /usr/bin/bash

/usr/bin/top -b -i -n 2 -c < /dev/null >> /opt/opengeofiction/sys-stats/$(date +%Y%m%d).txt 2>&1

