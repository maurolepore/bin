#!/bin/bash
# Renames files replacing spaces (including Unicode) with hyphens
# Usage: ./rename-screenshots.sh <directory>

if [ -z "$1" ]; then
    echo "Usage: $0 <directory>"
    echo "Example: $0 ~/Downloads/screenshots/"
    exit 1
fi

cd "$1" || exit 1

for file in *; do
    [ -f "$file" ] || continue
    # Replace regular space and narrow no-break space (U+202F) with hyphens
    newname=$(echo "$file" | sed 's/ /-/g' | sed $'s/\xE2\x80\xAF/-/g')
    if [ "$file" != "$newname" ]; then
        mv "$file" "$newname"
        echo "Renamed: $file -> $newname"
    fi
done
