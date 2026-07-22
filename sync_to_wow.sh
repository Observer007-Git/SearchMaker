#!/bin/zsh
SRC="/Users/fx/Documents/wow/SearchMaker"
DST="/Applications/World of Warcraft/_retail_/Interface/AddOns/SearchMaker"
mkdir -p "$DST"
rsync -a --delete --delete-excluded \
    --exclude '.DS_Store' \
    --exclude '.gitignore' \
    --exclude 'Tests/' \
    --exclude 'sync_to_wow.sh' \
    "$SRC/" "$DST/"
echo "SYNC OK"
