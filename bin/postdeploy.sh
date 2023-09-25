#!/bin/bash
# usage: /app/mattermost/bin/postdeploy

export MM_SERVICESETTINGS_LISTENADDRESS=":${PORT}"

plugins_list=$(find /app/postdeploy_plugins/. -maxdepth 1 -name '*.tar.gz' | tr '\n' ',')

for plugin in $(echo "$plugins_list" | tr ',' '\n')
do
  /app/bin/mattermost plugin add "$plugin"
done
