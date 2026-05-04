# # immich api key: "iZjKWTmj31NcHfI37vL31CYU9KoNqjFlDpcGmrflZM"

# #!/usr/bin/env bash
# set -euo pipefail

# DATA_DIR="${DATA_DIR:-/mnt/client-data}"
# PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# # Default values
# IMMICH_API_KEY="${IMMICH_API_KEY:-}"
# ALBUMS="${ALBUMS:-}"

# echo "Using project dir: $PROJECT_DIR"
# echo "Using data dir: $DATA_DIR"

# # Create main folders
# mkdir -p "$DATA_DIR/immichframe/Config"

# # Generate ImmichFrame config
# SETTINGS_FILE="$DATA_DIR/immichframe/Config/Settings.yaml"
# TEMPLATE_FILE="$PROJECT_DIR/templates/immichframe/Config/Settings.yaml"

# # Copy template first
# cp "$TEMPLATE_FILE" "$SETTINGS_FILE"

# # Update ApiKey if provided
# if [ -n "$IMMICH_API_KEY" ]; then
#   sed -i "s/ApiKey: \"\"/ApiKey: \"$IMMICH_API_KEY\"/" "$SETTINGS_FILE"
# fi

# # Update Albums if provided
# if [ -n "$ALBUMS" ]; then
#   # Replace the commented Albums section with actual album IDs
#   ALBUMS_YAML=""
#   IFS=',' read -ra ALBUM_ARRAY <<< "$ALBUMS"
#   for album in "${ALBUM_ARRAY[@]}"; do
#     ALBUMS_YAML="${ALBUMS_YAML}    - \"$album\"\n"
#   done
  
#   # Use awk to replace the Albums section
#   awk -v albums="$ALBUMS_YAML" '
#   /^    Albums:$/ {
#     print
#     getline
#     if ($0 ~ /^[[:space:]]*#[[:space:]]*-/) {
#       n = split(albums, lines, "\\n")
#       for (i = 1; i < n; i++) {
#         if (lines[i] != "") print lines[i]
#       }
#       next
#     }
#   }
#   { print }
#   ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
# fi

# echo "Created ImmichFrame Settings.yaml with provided configuration."

# # Permissions
# CURRENT_UID="${SUDO_UID:-$(id -u)}"
# CURRENT_GID="${SUDO_GID:-$(id -g)}"

# sudo chown -R "$CURRENT_UID:$CURRENT_GID" "$DATA_DIR"

# echo ""
# echo "Init completed."
# echo "Data folder is ready at: $DATA_DIR"