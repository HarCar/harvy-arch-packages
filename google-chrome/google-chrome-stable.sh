#!/bin/bash

config_home=${XDG_CONFIG_HOME:-$HOME/.config}
if [[ -f "$config_home/chrome-flags.conf" ]]; then
    chrome_flags=$(grep -v '^#' "$config_home/chrome-flags.conf")
fi

exec /opt/google/chrome/google-chrome $chrome_flags "$@"
