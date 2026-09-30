#!/bin/bash
set -euo pipefail

ENGINE_REV="42d3d75a56efe1a2e9902f52dc8006099c45d937"
ENGINE_SHORT="${ENGINE_REV:0:12}"
ENGINE_ROOT="${1:-${RUNNER_TEMP:-$PWD}/flutter-engine-${ENGINE_SHORT}}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$REPO_ROOT/resources/web/flutter_web/canvaskit-catalina"
DEPOT_TOOLS_DIR="${DEPOT_TOOLS_DIR:-${RUNNER_TEMP:-$PWD}/depot_tools}"

command -v git >/dev/null
command -v python3 >/dev/null

echo "== Catalina CanvasKit build =="
echo "Engine revision: $ENGINE_REV"
echo "Engine workspace: $ENGINE_ROOT"
echo "Output directory: $OUT_DIR"

# Flutter Engine's web build expects a gclient workspace whose Flutter engine
# checkout is src/flutter, with the Emscripten SDK enabled in custom_vars.
if ! command -v gclient >/dev/null 2>&1; then
  if [[ ! -d "$DEPOT_TOOLS_DIR/.git" ]]; then
    rm -rf "$DEPOT_TOOLS_DIR"
    git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git "$DEPOT_TOOLS_DIR"
  fi
  export PATH="$DEPOT_TOOLS_DIR:$PATH"
fi

if ! command -v gclient >/dev/null 2>&1; then
  echo "ERROR: gclient is not available after installing depot_tools." >&2
  exit 2
fi

mkdir -p "$ENGINE_ROOT"
if [[ ! -f "$ENGINE_ROOT/.gclient" ]]; then
  cat > "$ENGINE_ROOT/.gclient" <<'EOF'
solutions = [
  {
    "managed": False,
    "name": "src/flutter",
    "url": "https://github.com/flutter/engine.git",
    "custom_deps": {},
    "deps_file": "DEPS",
    "safesync_url": "",
    "custom_vars": {
      "download_emsdk": True,
    },
  },
]
EOF
fi

if [[ ! -d "$ENGINE_ROOT/src/flutter/.git" ]]; then
  mkdir -p "$ENGINE_ROOT/src"
  git clone --filter=blob:none --no-tags \
    https://github.com/flutter/engine.git \
    "$ENGINE_ROOT/src/flutter"
fi

cd "$ENGINE_ROOT"

# Pin the actual engine checkout used by flutter_bootstrap's buildConfig.
gclient sync --no-history --shallow -D -r "src/flutter@${ENGINE_REV}"

# Ensure the detached checkout exactly matches the required revision.
git -C "$ENGINE_ROOT/src/flutter" fetch --depth 1 origin "$ENGINE_REV"
git -C "$ENGINE_ROOT/src/flutter" checkout --detach "$ENGINE_REV"

# The distributed Flutter CanvasKit used by this app contains WebAssembly SIMD,
# which older WebKit versions on Catalina cannot validate. Disable the explicit
# SIMD compiler flag and LLVM vectorization for the locally-built scalar variant.
python3 - <<'PY'
from pathlib import Path

roots = [
    Path("src/flutter/third_party/skia"),
    Path("src/flutter/lib/web_ui"),
    Path("src/flutter/tools"),
]
changed = []
for root in roots:
    if not root.exists():
        continue
    for p in root.rglob("*"):
        if not p.is_file() or p.stat().st_size > 2_000_000:
            continue
        try:
            s = p.read_text()
        except Exception:
            continue
        if "-msimd128" in s or "-mrelaxed-simd" in s:
            ns = s.replace("-msimd128", "").replace("-mrelaxed-simd", "")
            if ns != s:
                p.write_text(ns)
                changed.append(str(p))
print(f"Removed explicit WASM SIMD flags from {len(changed)} engine source/build files")
for p in changed[:100]:
    print(" ", p)
PY

# Emscripten documents EMCC_CFLAGS as a compile/link environment hook. Keep
# the scalar flags last in this environment so they override SIMD defaults
# when the engine invokes emcc/em++.
export EMCC_CFLAGS="${EMCC_CFLAGS:-} -mno-simd128 -mno-relaxed-simd -fno-vectorize -fno-slp-vectorize"

export PATH="$ENGINE_ROOT/src/flutter/lib/web_ui/dev:$PATH"
cd "$ENGINE_ROOT/src/flutter/lib/web_ui"

# Use the exact engine checkout's felt tool to build Flutter's CanvasKit target.
# A normal felt build produces the release artifacts unless --debug/--profile
# is supplied; we intentionally do not request either of those modes.
felt build canvaskit

# Prefer the release output and fall back only if this exact engine revision
# names its output directory differently.
WASM=""
JS=""
for build_dir in \
  "$ENGINE_ROOT/out/wasm_release" \
  "$ENGINE_ROOT/src/flutter/out/wasm_release" \
  "$ENGINE_ROOT/out/wasm_profile" \
  "$ENGINE_ROOT/src/flutter/out/wasm_profile" \
  "$ENGINE_ROOT/out/wasm_debug" \
  "$ENGINE_ROOT/src/flutter/out/wasm_debug"
do
  if [[ -s "$build_dir/canvaskit.wasm" && -s "$build_dir/canvaskit.js" ]]; then
    WASM="$build_dir/canvaskit.wasm"
    JS="$build_dir/canvaskit.js"
    break
  fi
done

if [[ -z "$WASM" || -z "$JS" ]]; then
  echo "ERROR: CanvasKit artifacts were not found after felt build." >&2
  find "$ENGINE_ROOT" -type f \( -name canvaskit.wasm -o -name canvaskit.js \) -print | head -100 >&2 || true
  exit 3
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
cp "$WASM" "$OUT_DIR/canvaskit.wasm"
cp "$JS" "$OUT_DIR/canvaskit.js"

echo "Generated:"
ls -lh "$OUT_DIR/canvaskit.wasm" "$OUT_DIR/canvaskit.js"

# The GitHub workflow runs a wasm2wat-based scalar validation immediately after
# this script. Keep this script focused on producing the artifacts.
echo "Catalina CanvasKit written to: $OUT_DIR"
