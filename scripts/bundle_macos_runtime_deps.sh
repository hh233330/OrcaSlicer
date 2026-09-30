#!/bin/bash
set -euo pipefail

APP="${1:?usage: bundle_macos_runtime_deps.sh APP ARCH DEPS_PREFIX}"
ARCH="${2:?usage: bundle_macos_runtime_deps.sh APP ARCH DEPS_PREFIX}"
DEPS_PREFIX="${3:?usage: bundle_macos_runtime_deps.sh APP ARCH DEPS_PREFIX}"

EXECUTABLE="$APP/Contents/MacOS/Snapmaker_Orca"
FRAMEWORKS="$APP/Contents/Frameworks"

if [[ ! -f "$EXECUTABLE" ]]; then
  echo "ERROR: main executable not found: $EXECUTABLE" >&2
  exit 1
fi

mkdir -p "$FRAMEWORKS"

echo "Bundling macOS runtime dependencies for $ARCH"
echo "App: $APP"
echo "Deps prefix: $DEPS_PREFIX"

# The Catalina build currently has one known non-system dynamic dependency:
# zstd from Homebrew. The build machine encodes an absolute Homebrew path in
# the Mach-O load command, which is not present on a clean user Mac.
ZSTD_SRC=""
if [[ -f "$DEPS_PREFIX/usr/local/lib/libzstd.1.dylib" ]]; then
  ZSTD_SRC="$DEPS_PREFIX/usr/local/lib/libzstd.1.dylib"
fi

if [[ -z "$ZSTD_SRC" ]] && command -v brew >/dev/null 2>&1; then
  ZSTD_PREFIX="$(brew --prefix zstd 2>/dev/null || true)"
  if [[ -n "$ZSTD_PREFIX" && -f "$ZSTD_PREFIX/lib/libzstd.1.dylib" ]]; then
    ZSTD_SRC="$ZSTD_PREFIX/lib/libzstd.1.dylib"
  fi
fi

if [[ -z "$ZSTD_SRC" ]]; then
  echo "ERROR: Could not locate libzstd.1.dylib in the dependency prefix or Homebrew." >&2
  exit 1
fi

ZSTD_DST="$FRAMEWORKS/libzstd.1.dylib"
cp -fL "$ZSTD_SRC" "$ZSTD_DST"
chmod 755 "$ZSTD_DST"

# Give the bundled dylib an app-local install name.
install_name_tool -id "@rpath/libzstd.1.dylib" "$ZSTD_DST"

# Add an app-local rpath if it is missing.
if ! otool -l "$EXECUTABLE" | grep -A2 'cmd LC_RPATH' | grep -Fq '@executable_path/../Frameworks'; then
  install_name_tool -add_rpath '@executable_path/../Frameworks' "$EXECUTABLE"
fi

# Rewrite any Homebrew zstd reference in the main executable to the bundled copy.
while IFS= read -r dep; do
  [[ -n "$dep" ]] || continue
  case "$dep" in
    /usr/local/opt/zstd/*/libzstd.1.dylib|/usr/local/opt/zstd/lib/libzstd.1.dylib|/usr/local/Cellar/zstd/*/lib/libzstd.1.dylib|/opt/homebrew/opt/zstd/*/libzstd.1.dylib|/opt/homebrew/Cellar/zstd/*/lib/libzstd.1.dylib)
      install_name_tool -change "$dep" '@rpath/libzstd.1.dylib' "$EXECUTABLE"
      ;;
  esac
done < <(otool -L "$EXECUTABLE" | tail -n +2 | sed -E 's/^[[:space:]]*([^[:space:]]+).*/\1/')

# Remove build-machine rpaths. Any runtime dependency that remains must be
# self-contained in the app or be a system library.
while IFS= read -r rpath; do
  [[ -n "$rpath" ]] || continue
  case "$rpath" in
    /Users/runner/work/*|/usr/local/lib|/opt/homebrew/lib)
      install_name_tool -delete_rpath "$rpath" "$EXECUTABLE" 2>/dev/null || true
      ;;
  esac
done < <(otool -l "$EXECUTABLE" | awk '/cmd LC_RPATH/{getline; if ($1=="path") print $2}')

# Verify that the executable now refers to the bundled zstd and no build-host
# Homebrew path remains.
if ! otool -L "$EXECUTABLE" | grep -Fq '@rpath/libzstd.1.dylib'; then
  echo "ERROR: @rpath/libzstd.1.dylib is not present in executable dependencies." >&2
  otool -L "$EXECUTABLE" >&2
  exit 1
fi

if otool -L "$EXECUTABLE" | grep -Eq '/usr/local/(opt|Cellar)/|/opt/homebrew/(opt|Cellar)/'; then
  echo "ERROR: build-host Homebrew dependency remains:" >&2
  otool -L "$EXECUTABLE" >&2
  exit 1
fi

# Re-sign ad hoc after install_name_tool modifications.
codesign --force --sign - "$ZSTD_DST" >/dev/null 2>&1 || true
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "Bundled runtime dependencies:"
ls -lh "$FRAMEWORKS"
echo "Final main executable dependencies:"
otool -L "$EXECUTABLE"
