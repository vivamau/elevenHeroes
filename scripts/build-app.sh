#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/import-countries.py
python3 scripts/prepare-player-profiles.py
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
APP="$PWD/dist/Eleven Heroes.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" .build/universal
for ARCH in arm64 x86_64; do
  xcrun swiftc -disable-sandbox -swift-version 6 -O -parse-as-library -target "$ARCH-apple-macos14.0" -sdk "$(xcrun --show-sdk-path)" -I Sources/CSQLite Sources/ElevenHeroes/*.swift -o ".build/universal/ElevenHeroes-$ARCH"
done
lipo -create .build/universal/ElevenHeroes-arm64 .build/universal/ElevenHeroes-x86_64 -output "$APP/Contents/MacOS/ElevenHeroes"
cp db/team_details.json "$APP/Contents/Resources/team_details.json"
cp db/countries.json "$APP/Contents/Resources/countries.json"
cp db/db.sqlite "$APP/Contents/Resources/db.sqlite"
cp db/player_profiles.json "$APP/Contents/Resources/player_profiles.json"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ElevenHeroes</string>
<key>CFBundleIdentifier</key><string>com.elevenheroes.game</string>
<key>CFBundleName</key><string>Eleven Heroes</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
echo "Built: $APP"
lipo -info "$APP/Contents/MacOS/ElevenHeroes"
