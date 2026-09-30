# Snapmaker OrcaSlicer 2.4.0 — macOS Catalina 10.15 / Intel x86_64

This tree adapts Snapmaker OrcaSlicer 2.4.0 for an Intel Mac on macOS Catalina 10.15.7.

## Home / Device white screen (Catalina)

On Catalina the Home and Device pages run inside WKWebView + Flutter CanvasKit. The previous "app can launch" tree still showed a blank page or an endless spinner because:

1. `index.html` blocked on a PostHog script from `cdn.jsdelivr.net` (often unreachable in China), so the page never reached the Flutter bootstrap.
2. CanvasKit JS used ES2021 `||=` / `&&=`, which Safari 13.1 / WebKit 605 cannot parse, so the renderer never started.
3. The loading overlay used CSS `inset` (Safari 14.1+), so Catalina painted a tiny spinner on a white page.
4. WKWebView used a transparent layer. Combined with WebGL/CanvasKit this composites to a blank white page on 10.15.

Fixes in this tree (in-app WebView, no external browser):

- Drop the blocking CDN script; keep an opaque page background.
- Rewrite CanvasKit `||=` / `&&=` to ES2020-compatible assignments.
- Replace overlay `inset` with `top/right/bottom/left`; replace flex `gap` with margins.
- Force the canvaskit renderer and fall back to CPU Skia if WebGL is missing.
- On macOS 10.15, give WKWebView an opaque themed background.
- Bump `resources/web/flutter_web/version.json` so an older cached copy in Application Support is replaced.

## Earlier Catalina changes (still in this tree)

- macOS deployment target: **10.15** (x86_64 only).
- App `LSMinimumSystemVersion`: **10.15**.
- Sentry/Crashpad disabled on Catalina.
- Automatic Flutter Web OTA updates disabled on Catalina.
- Local HTTP server already binds `127.0.0.1` and serves `.wasm` as `application/wasm`.

## Build

On the Catalina (or any Intel) Mac with Xcode:

```bash
xcode-select --install
brew install cmake gettext libtool automake autoconf texinfo ninja git

cd /path/to/OrcaSlicer-main
chmod +x build_release_macos.sh scripts/*.sh 2>/dev/null
./build_release_macos.sh -a x86_64 -t 10.15
./scripts/sign_and_package.sh x86_64
```

After installing:

```bash
xattr -dr com.apple.quarantine "/Applications/Snapmaker Orca.app"
rm -rf ~/Library/Application\ Support/Snapmaker_Orca/web/flutter_web
```


### GitHub Actions
The Catalina workflow is designed for GitHub repository uploads. It restores the executable bit and invokes the CanvasKit builder through `bash`, so the repository does not depend on Git preserving the shell script mode bit. It also validates the generated Catalina CanvasKit WASM with `wasm2wat` before building the application.
