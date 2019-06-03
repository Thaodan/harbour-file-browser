#!/bin/bash

root="../src/icons"
for i in 86 108 128 172; do
    mkdir -p "$root/${i}x$i"
    inkscape -z -e "$root/${i}x$i/harbour-file-browser.png" -w "$i" -h "$i" harbour-file-browser.svg
done

root="../src/qml/images"
files=(toolbar-rename@64 harbour-file-browser@86)
mkdir -p "$root"

for img in "${files[@]}"; do
    inkscape -z -e "$root/${img%@*}.png" -w "${img#*@}" -h "${img#*@}" "${img%@*}.svg"
done


echo "rendering file icons..."

files=(file-stack)
mkdir -p "$root"

for img in "${files[@]}"; do
    skip=

    if [[ "${img%@*}.svg" -nt "$root/large-${img%@*}.png" ]]; then
        inkscape -z -e "$root/large-${img}.png" -w "128" -h "128" "${img}.svg"
    else
        skip+="large "
    fi

    if [[ "${img%@*}.svg" -nt "$root/small-${img%@*}.png" ]]; then
        inkscape -z -e "$root/small-${img}.png" -w "32" -h "32" "${img}.svg"
    else
        skip+="small"
    fi

    if [[ -n "$skip" ]]; then
        echo "nothing to do for '${img}.svg': $skip"
    fi
done
