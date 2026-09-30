# GitHub Actions: Catalina 10.15 x86_64 build

1. Upload the entire `OrcaSlicer-main` directory contents to a GitHub repository.
2. Open **Actions**.
3. Select **Build Snapmaker Orca 2.4.0 - Catalina Intel x86_64**.
4. Click **Run workflow**.
5. Wait for the job to finish.
6. Download the artifact named `Snapmaker_Orca_2.4.0_Catalina_x86_64`.

Important:
- The workflow uses `macos-15-intel` to build Intel x86_64 binaries with a 10.15 minimum deployment target.
- The workflow invokes `scripts/build_catalina_canvaskit.sh` through `bash` after `chmod +x`, so GitHub web uploads that lose the executable bit do not fail with `Permission denied`.
- The CanvasKit helper creates a separate `resources/web/flutter_web/canvaskit-catalina/` directory from the exact Flutter engine revision embedded in the app's Flutter bootstrap.
- The workflow installs `wabt` and rejects the build if the generated Catalina CanvasKit WASM still contains WebAssembly SIMD instructions.
- The repository does not contain the generated Catalina WASM. GitHub Actions generates it during the build.

This package has been statically checked for shell syntax, JavaScript syntax, Web asset hashes, workflow YAML parsing, and archive integrity. A successful GitHub run and a successful Catalina 10.15.7 launch still require an actual CI run and real-machine test.
