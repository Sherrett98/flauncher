#!/bin/bash
# Installs the Sofa home screen on your Fire TV over Wi-Fi.
# Double-click it on your Mac, or run:  bash install-sofa.command [tv-ip]
# Run it again any time to update Sofa to the latest build.

TV="${1:-192.168.0.15}"
REPO="Sherrett98/flauncher"
WORK="$HOME/.sofa-install"

mkdir -p "$WORK" && cd "$WORK" || exit 1
say() { printf "\n\033[1m%s\033[0m\n" "$*"; }
fail() { printf "\n\033[31m%s\033[0m\n" "$*"; read -r -p "Press Return to close."; exit 1; }

# 1. adb (Google's tool for talking to Android devices)
ADB="$(command -v adb)"
[ -z "$ADB" ] && [ -x "$HOME/Library/Android/sdk/platform-tools/adb" ] && ADB="$HOME/Library/Android/sdk/platform-tools/adb"
[ -z "$ADB" ] && [ -x "$WORK/platform-tools/adb" ] && ADB="$WORK/platform-tools/adb"
if [ -z "$ADB" ]; then
  say "Downloading adb from Google (one-off)..."
  curl -fsSL -o platform-tools.zip https://dl.google.com/android/repository/platform-tools-latest-darwin.zip \
    && unzip -qo platform-tools.zip && ADB="$WORK/platform-tools/adb" || fail "Couldn't download adb."
fi
"$ADB" start-server >/dev/null 2>&1

# 2. Connect to the TV
say "Connecting to the TV at $TV..."
echo "If a box pops up on the TV, use the Fire TV phone app to tick 'Always allow from this computer' and choose OK."
"$ADB" connect "$TV:5555" >/dev/null
STATE=""
for _ in $(seq 1 45); do
  STATE="$("$ADB" -s "$TV:5555" get-state 2>/dev/null)"
  [ "$STATE" = "device" ] && break
  [ -z "$STATE" ] && "$ADB" connect "$TV:5555" >/dev/null 2>&1
  sleep 2
done
[ "$STATE" = "device" ] || fail "Couldn't connect. Check ADB debugging is on (Settings > My Fire TV > Developer options), that the Mac is on the same Wi-Fi, then run this again."
A=("$ADB" -s "$TV:5555")
echo "Connected to $("${A[@]}" shell settings get global device_name 2>/dev/null | tr -d '\r')."

# 3. Sofa itself
say "Downloading the latest Sofa build..."
curl -fL --progress-bar -o sofa.apk "https://github.com/$REPO/releases/latest/download/sofa.apk" \
  || fail "No Sofa build to download yet. Check https://github.com/$REPO/actions"

say "Installing Sofa..."
OUT="$("${A[@]}" install -r sofa.apk 2>&1)"
if ! echo "$OUT" | grep -q Success; then
  if echo "$OUT" | grep -q INSTALL_FAILED_UPDATE_INCOMPATIBLE; then
    echo "The installed copy was signed differently, so reinstalling it fresh."
    "${A[@]}" uninstall me.efesser.flauncher >/dev/null
    "${A[@]}" install sofa.apk | grep -q Success || fail "Install failed."
  else
    echo "$OUT"; fail "Install failed."
  fi
fi
echo "Sofa installed."

# 4. Home on Fire, which sends the Home button to Sofa
#    (Launcher Manager Mini's triggers don't fire on this TV's Fire OS build.)
if "${A[@]}" shell pm list packages io.github.toolicious.homeonfire | grep -q homeonfire; then
  say "Done. Sofa is updated."
  echo "Home on Fire is already set up, so nothing else to do. Press Home to see the new version."
else
  "${A[@]}" uninstall com.wolf.minilm >/dev/null 2>&1
  say "Installing Home on Fire..."
  curl -fL --progress-bar -o home-on-fire.apk https://github.com/toolicious/home-on-fire/releases/latest/download/home-on-fire.apk \
    || fail "Couldn't download Home on Fire."
  "${A[@]}" install -r home-on-fire.apk | grep -q Success || fail "Couldn't install Home on Fire."
  "${A[@]}" shell pm grant io.github.toolicious.homeonfire android.permission.WRITE_SECURE_SETTINGS
  "${A[@]}" shell am start -n io.github.toolicious.homeonfire/.MainActivity >/dev/null
  say "Last bit, on the TV with the phone app:"
  echo "Home on Fire is now open on the TV."
  echo "  1. Switch on Accessibility service."
  echo "  2. Choose target app: Sofa."
  echo "  3. Switch on Replace Home button and Launch on boot, then press Home."
fi
echo
echo "To update Sofa later, just run this again."
read -r -p "Press Return to close."
