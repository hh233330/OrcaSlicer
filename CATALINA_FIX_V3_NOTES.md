# Catalina 10.15 / Orca 2.4.0 v3 修复包

## 目标
针对 macOS Catalina 10.15.7（19H2026 / Safari 15.6.1）上的 Flutter Web Home/Device 白屏。

## 这版修了什么
1. 修复上一版 flutter loader 中导致 `SyntaxError: Return statements are only valid inside functions` 的错误补丁。
2. bootstrap / loader 路径中去掉旧 WebKit 可能触发的现代 JS 操作符。
3. Catalina UA 自动选择 `canvaskit-catalina/`，其他系统继续使用 `canvaskit/`。
4. 增加 `scripts/build_catalina_canvaskit.sh`：在有 Flutter Engine/depot_tools 构建环境的机器上，按同一 engine revision 生成不带 SIMD 编译参数的 CanvasKit，并安装到 `resources/web/flutter_web/canvaskit-catalina/`。

## 重要
这个补丁包本身没有携带生成后的 `canvaskit-catalina/canvaskit.wasm` 二进制，因为它必须在完整 Flutter Engine 构建环境中按当前 engine revision 生成；不能拿别的 revision 的 WASM 直接替换，否则有 JS/WASM API ABI 不匹配风险。

## 使用
在完整源码根目录执行：

```bash
unzip -o /path/to/OrcaSlicer-2.4.0-Catalina-home-device-fix-v3-patch.zip
chmod +x scripts/build_catalina_canvaskit.sh
./scripts/build_catalina_canvaskit.sh
```

确认存在：

```text
resources/web/flutter_web/canvaskit-catalina/canvaskit.js
resources/web/flutter_web/canvaskit-catalina/canvaskit.wasm
```

然后按项目原有 macOS release 脚本重新构建/打包。

首次在 Catalina 测试前建议清掉用户缓存：

```bash
rm -rf "$HOME/Library/Application Support/Snapmaker_Orca/web/flutter_web"
```

