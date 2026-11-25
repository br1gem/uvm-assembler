#!/bin/sh

script_dir="$(CDPATH= cd "$(dirname "$0")" && pwd)" || exit 1
exec env -u TOOLCHAINS -u SDKROOT /usr/bin/xcrun --sdk macosx \
    swift "$script_dir/src/interpreter.swift" "$@"