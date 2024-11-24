#!/bin/bash
# ogf set read-only v0.1
# 20220811 luciano
# this places the server in read only status from online status
sed -i 's|status: "online"|status: "api_readonly"|g' /var/www/html/opengeofiction.net/config/settings.yml
