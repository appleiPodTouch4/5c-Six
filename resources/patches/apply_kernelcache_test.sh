#!/bin/bash
set -e
SRC="/Users/mry0000/Desktop/5c6/runtime/firmware/iPhone5,3/6.1.4-hacktivate-yes-native6-wifi-candidate-baseband-native-baseband-0x23702139df0/inputs/n42-kernel.macho"
DIR="/Users/mry0000/Desktop/5c-Six/resources/boot-patches"
OUT="/tmp/kernelcache.test.macho"
apply_table() {
    local tbl="$1"
    while IFS=' ' read -r off hex; do
        [ -z "$off" ] && continue
        printf '%b' "$(echo "$hex" | sed 's/../\\x&/g')" | dd of="$OUT" bs=1 seek="$off" conv=notrunc 2>/dev/null
    done < "$tbl"
}
cp "$SRC" "$OUT"
apply_table "$DIR/kernelcache_n48.patches"   # phase 1: 148 structural edits
apply_table "$DIR/kernelcache_n48.repl"      # phase 2: muscat -> barolo
cat "$DIR/kernelcache_n48.tail" >> "$OUT"
echo "done: $(ls -l "$OUT" | awk '{print $5}') bytes"
