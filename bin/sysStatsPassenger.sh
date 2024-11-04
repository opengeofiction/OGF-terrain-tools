#! /usr/bin/bash

mkdir -p /opt/opengeofiction/sys-stats/passenger/$(date +%Y%m%d)
/usr/sbin/passenger-status > /opt/opengeofiction/sys-stats/passenger/$(date +%Y%m%d)/$(date +%H%M).txt
/usr/sbin/passenger-status --show=requests >> /opt/opengeofiction/sys-stats/passenger/$(date +%Y%m%d)/$(date +%H%M).txt
