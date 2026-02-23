#!/bin/bash
#
# Reorganize fastlane screenshots from per-locale folders into per-screen folders.
#
# Before:  screenshots/en-US/Screenshot-en-US-01-Lines.png
# After:   screenshots_organized/01-Lines/01-en-US.png
#
# Before:  screenshots_ipad/en-US/Screenshot-iPad-en-US-01-Lines.png
# After:   screenshots_ipad_organized/01-Lines/01-en-US.png

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Language order for App Store Connect
LANGUAGES=(
    "en-US"
    "fr-FR"
)

organize() {
    local src_dir="$1"
    local out_dir="$2"
    local prefix="$3" # "Screenshot" or "Screenshot-iPad"

    if [ ! -d "$src_dir" ]; then
        echo "Skipping $src_dir (not found)"
        return
    fi

    rm -rf "$out_dir"
    mkdir -p "$out_dir"

    for i in "${!LANGUAGES[@]}"; do
        local lang="${LANGUAGES[$i]}"
        local lang_num
        lang_num=$(printf "%02d" $((i + 1)))
        local lang_dir="$src_dir/$lang"

        if [ ! -d "$lang_dir" ]; then
            echo "  Warning: no screenshots for $lang"
            continue
        fi

        for file in "$lang_dir"/*.png; do
            [ -f "$file" ] || continue
            local basename
            basename="$(basename "$file")"

            # Extract the NN-Name part from the filename
            # Screenshot-en-US-01-Lines.png       -> 01-Lines
            # Screenshot-iPad-en-US-01-Lines.png   -> 01-Lines
            local screen_name
            screen_name="$(echo "$basename" | sed -E "s/^${prefix}-${lang}-//" | sed 's/\.png$//')"

            mkdir -p "$out_dir/$screen_name"
            cp "$file" "$out_dir/$screen_name/${lang_num}-${lang}.png"
        done
    done

    echo "Organized: $out_dir"
}

echo "Organizing iPhone screenshots..."
organize "$SCRIPT_DIR/screenshots" "$SCRIPT_DIR/screenshots_organized" "Screenshot"

echo "Organizing iPad screenshots..."
organize "$SCRIPT_DIR/screenshots_ipad" "$SCRIPT_DIR/screenshots_ipad_organized" "Screenshot-iPad"

echo "Done."
