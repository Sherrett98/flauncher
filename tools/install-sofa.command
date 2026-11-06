#!/bin/bash
# Installs the Sofa home screen on your Fire TV over Wi-Fi.
# Double-click it on your Mac, or run:  bash install-sofa.command [tv-ip]
# Run it again any time to update Sofa to the latest build.

TV="${1:-192.168.0.15}"
REPO="Sherrett98/flauncher"
WORK="$HOME/.sofa-install"
LM_APK="https://xdaforums.com/attachments/lm-mini-v2-apk.6368054/"
LM_THREAD="https://xdaforums.com/t/app-firetv-noroot-launcher-manager-change-launcher-without-root.4176349/"

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

# 4. Launcher Manager Mini, which sends the Home button to Sofa
if "${A[@]}" shell pm list packages com.wolf.minilm | grep -q minilm; then
  echo "Launcher Manager Mini is already on the TV."
else
  LM="$(ls -t "$HOME"/Downloads/*.apk 2>/dev/null | grep -i -E 'lm.?mini|launcher.?manager|minilm' | head -1)"
  if [ -z "$LM" ]; then
    say "Downloading Launcher Manager Mini from XDA..."
    if curl -fsSL -A "Mozilla/5.0" -o "$WORK/lm-mini-v2.apk" "$LM_APK" && [ "$(head -c 2 "$WORK/lm-mini-v2.apk")" = "PK" ]; then
      LM="$WORK/lm-mini-v2.apk"
    fi
  fi
  if [ -z "$LM" ]; then
    say "One manual download needed"
    echo "Download 'LM Mini v2.apk' from the first post of the XDA thread that's opening now."
    echo "Save it to Downloads, then run this installer again."
    open "$LM_THREAD"
    read -r -p "Press Return to close."; exit 0
  fi
  say "Installing Launcher Manager Mini ($(basename "$LM"))..."
  "${A[@]}" install -r "$LM" | grep -q Success || fail "Couldn't install $LM."
fi

say "Giving Launcher Manager Mini its permissions..."
"${A[@]}" shell appops set com.wolf.minilm SYSTEM_ALERT_WINDOW allow
"${A[@]}" shell pm grant com.wolf.minilm android.permission.READ_LOGS
"${A[@]}" shell dumpsys deviceidle whitelist +com.wolf.minilm >/dev/null
"${A[@]}" shell am force-stop com.wolf.minilm
"${A[@]}" shell monkey -p com.wolf.minilm -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1

say "Last bit, on the TV with the phone app:"
echo "Launcher Manager Mini is now open on the TV."
echo "  1. Choose My Launcher and pick Sofa."
echo "  2. Tick Launch on Boot."
echo "  3. Turn the custom launcher on, then press Home."
echo
echo "To update Sofa later, just run this again."
read -r -p "Press Return to close."
