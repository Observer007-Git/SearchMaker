#!/bin/zsh
set -euo pipefail

ADDON_ROOT="${0:A:h:h}"

find "$ADDON_ROOT" -name '*.lua' -print0 | xargs -0 -n1 luac -p
lua "$ADDON_ROOT/Tests/ServiceTest.lua" "$ADDON_ROOT"
xmllint --noout "$ADDON_ROOT/Bindings.xml"

while IFS= read -r addon_file; do
    [[ -z "$addon_file" || "$addon_file" == \#* ]] && continue
    [[ -f "$ADDON_ROOT/$addon_file" ]] || {
        echo "Missing TOC file: $addon_file" >&2
        exit 1
    }
done < "$ADDON_ROOT/SearchMaker.toc"

echo "SearchMaker static checks passed"
