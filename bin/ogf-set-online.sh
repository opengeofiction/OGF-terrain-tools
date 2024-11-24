#!/bin/bash
# ogf set read-only v0.1
# 20220811 luciano
# this places the server in online status from read only status
sed -i 's|status: "api_readonly"|status: "online"|g' /var/www/html/opengeofiction.net/config/settings.yml
