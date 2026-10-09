# --- часть 1 ---
set -euo pipefail
GODOT_VERSION="4.3"
GAME_SCRIPT="main.gd"
PACKAGE_NAME="com.example.drive3d"
APP_NAME="Drive3D"
if [ ! -f "$GAME_SCRIPT" ]; then
echo "::error::Не найден $GAME_SCRIPT в корне репозитория"
exit 1
fi
# --- часть 2 ---
BASE="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"
curl -fsSL --retry 5 -o godot.zip "$BASE/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
curl -fsSL --retry 5 -o templates.tpz "$BASE/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
unzip -q godot.zip
sudo mv "Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot
sudo chmod +x /usr/local/bin/godot
TPL_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
mkdir -p "$TPL_DIR"
unzip -q templates.tpz -d tpl_tmp
mv tpl_tmp/templates/* "$TPL_DIR/"
rm -rf godot.zip templates.tpz tpl_tmp
godot --version
# --- часть 3 ---
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/usr/local/lib/android/sdk}}"
SDKM="$SDK/cmdline-tools/latest/bin/sdkmanager"
yes | "$SDKM" --licenses > /dev/null || true
"$SDKM" "platform-tools" "build-tools;34.0.0" "platforms;android-34" > /dev/null
keytool -genkeypair -v -keystore "$HOME/debug.keystore" -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" > /dev/null
mkdir -p "$HOME/.config/godot"
cat > "$HOME/.config/godot/editor_settings-4.3.tres" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$SDK"
export/android/java_sdk_path = "${JAVA_HOME:-}"
export/android/debug_keystore = "$HOME/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOF
# --- часть 4 ---
if [ ! -f project.godot ]; then
cat > project.godot <<'EOF'
config_version=5

[application]

config/name="Drive3D"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.3", "GL Compatibility")

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/handheld/orientation=4

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/vram_compression/import_etc2_astc=true
EOF
fi
if [ ! -f main.tscn ]; then
cat > main.tscn <<EOF
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://${GAME_SCRIPT}" id="1"]

[node name="Main" type="Node3D"]
script = ExtResource("1")
EOF
fi
cat > export_presets.cfg <<EOF
[preset.0]

name="Android"
platform="Android"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/drive3d.apk"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.0.options]

custom_template/debug=""
custom_template/release=""
gradle_build/use_gradle_build=false
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
version/code=1
version/name="1.0"
package/unique_name="${PACKAGE_NAME}"
package/name="${APP_NAME}"
package/signed=true
package/app_category=2
screen/immersive_mode=true
screen/support_small=true
screen/support_normal=true
screen/support_large=true
screen/support_xlarge=true
EOF
# --- часть 5 ---
mkdir -p build
timeout 300 godot --headless --import || true
godot --headless --export-debug "Android" "build/drive3d.apk"
ls -la build
