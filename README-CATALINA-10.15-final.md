# Catalina 10.15.7 / WKWebView compatibility patch

### 结论

这次的白屏不能只靠把 JavaScript 写法改成 ES5 来解决。当前 Web 资源使用 Flutter engine `42d3d75a...` / Flutter 3.41.9 的 CanvasKit WebAssembly，而 Catalina 10.15.7 使用的 Safari/WebKit 代际不支持 WebAssembly SIMD。要在 Catalina 真正跑起来，需要 **同一 Flutter engine revision 的非 SIMD CanvasKit**。

### 本补丁包含

- 修复上一版引入的 Flutter bootstrap 语法错误。
- 移除 loader/CanvasKit wrapper 中的 `??` / `?.` / `||=` / `&&=`，避免老 WebKit 解析问题。
- Catalina UA 下自动选择 `canvaskit-catalina/`。
- 提供 `scripts/build_catalina_canvaskit.sh`：固定 engine revision，同步 engine 依赖，去掉 CanvasKit 构建里的 `-msimd128`，再生成与该 engine 同源的 scalar CanvasKit。
- 正常系统继续使用现有 `canvaskit/`。

### 必须生成的两个文件

执行：

```bash
./scripts/build_catalina_canvaskit.sh
```

最终应存在：

```text
resources/web/flutter_web/canvaskit-catalina/canvaskit.js
resources/web/flutter_web/canvaskit-catalina/canvaskit.wasm
```

这两个文件不能拿随便一个旧 Flutter/CanvasKit 版本替换；Flutter engine 和 CanvasKit 的 binding/API 必须保持匹配。
