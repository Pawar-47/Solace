#!/usr/bin/env bash
#
# Collect everything a shader-pack report needs into one text file.
#
#   bash tools/collect_report.sh
#
# It writes solace-report.txt in the folder you run it from: the shader lines of the
# Minecraft log, the tail of that log, the kernel's GPU messages, your renderer and
# your system. Nothing is uploaded anywhere; it is a file you can read first and paste
# or attach afterwards.
#
# If your launcher keeps its instance somewhere unusual, edit LOG_HINTS at the top.

LOG_HINTS=(
    "$HOME/.minecraft/logs/latest.log"
    "$HOME/.local/share/PrismLauncher/instances"
    "$HOME/.local/share/multimc/instances"
    "$HOME/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances"
)

OUT="solace-report.txt"
: > "$OUT"

section() {
    printf '\n===== %s =====\n' "$1" >> "$OUT"
}

section "when"
date -u '+%Y-%m-%d %H:%M:%S UTC' >> "$OUT"

section "system"
uname -a >> "$OUT" 2>&1
if [ -f /etc/os-release ]; then
    cat /etc/os-release >> "$OUT" 2>&1
fi
java -version >> "$OUT" 2>&1 || echo "java not on PATH" >> "$OUT"

section "renderer (llvmpipe here means software rendering)"
if command -v glxinfo >/dev/null 2>&1; then
    glxinfo -B 2>&1 | head -40 >> "$OUT"
else
    echo "glxinfo is not installed: apt install mesa-utils" >> "$OUT"
fi

section "GPU messages from the kernel (a freeze shows here)"
if journalctl -k -b >/dev/null 2>&1; then
    journalctl -k -b 2>/dev/null | grep -i -E "gpu hang|i915|drm|reset|amdgpu|radeon" | tail -n 40 >> "$OUT"
elif dmesg >/dev/null 2>&1; then
    dmesg 2>/dev/null | grep -i -E "gpu hang|i915|drm|reset|amdgpu|radeon" | tail -n 40 >> "$OUT"
else
    echo "no readable kernel log (try: sudo dmesg | tail -n 50)" >> "$OUT"
fi

# Find the game logs.
LOGS=()
for hint in "${LOG_HINTS[@]}"; do
    if [ -f "$hint" ]; then
        LOGS+=("$hint")
    elif [ -d "$hint" ]; then
        while IFS= read -r found; do
            LOGS+=("$found")
        done < <(find "$hint" -maxdepth 3 -name latest.log -path '*logs*' 2>/dev/null | head -5)
    fi
done

section "shader and GL lines from the log"
if [ ${#LOGS[@]} -eq 0 ]; then
    echo "No Minecraft log found. Edit LOG_HINTS at the top of this script and run it again." >> "$OUT"
else
    for log in "${LOGS[@]}"; do
        printf '%s\n' "--- $log ---" >> "$OUT"
        grep -n -i -E "iris|shader|program|error|glsl|framebuffer|opengl" "$log" \
            | tail -n 100 >> "$OUT" 2>&1
    done
fi

section "tail of the log (the last thing it was doing)"
for log in "${LOGS[@]}"; do
    printf '%s\n' "--- $log ---" >> "$OUT"
    tail -n 200 "$log" >> "$OUT" 2>&1
done

section "which build was loaded"
echo "Say here which zip you loaded: Solace-LowEnd-v<version>.zip or Solace-Diagnostic.zip." >> "$OUT"

printf '%s\n' "" "report written to $(pwd)/$OUT"
