#!/bin/bash

config_home=${XDG_CONFIG_HOME:-$HOME/.config}
if [[ -f "$config_home/code-flags.conf" ]]; then
    code_flags=$(sed 's/#.*//' "$config_home/code-flags.conf" | tr '\n' ' ')
fi

exec /usr/share/code/bin/code "$@" $code_flags
