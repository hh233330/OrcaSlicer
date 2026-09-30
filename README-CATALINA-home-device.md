# Catalina 首页 / 设备页白屏修复说明

适用系统：macOS Catalina 10.15.7，Intel MacBook Pro 13-inch 2020
软件：Snapmaker OrcaSlicer 2.4.0（在“能打开但仍白屏”的源码上继续修）

## 你看到的现象

软件已经能启动，但首页和设备页是白的，或一直转圈。

这几页不是普通按钮界面，而是软件内嵌的网页。Catalina 自带的网页引擎比较旧，再加上海外脚本，页面就会卡在加载状态。

## 这次修了什么

1. **去掉会卡住的外网脚本**  
   首页会先去国外地址加载统计脚本。网络不通时，页面会一直白屏/转圈。已改为不再依赖它。

2. **让旧系统能读懂绘图脚本**  
   绘图引擎里有 Catalina 不认识的新写法，页面因此永远转圈。已改成旧系统能执行的写法。

3. **转圈提示改成铺满窗口**  
   旧系统不认某条样式，转圈只剩一个小点，看起来像白屏。已改成整页覆盖。

4. **网页背景改为不透明**  
   Catalina 上透明网页叠在一起会变成白屏。10.15 上改为不透明背景。

5. **更新网页版本号**  
   避免电脑里还在用以前缓存的旧网页文件。

页面仍然在软件内部打开，不会跳到浏览器。

## 请在这台 Mac 上重新编译

这是源码补丁，需要在 Mac + Xcode 里编一次：

```bash
xcode-select --install
brew install cmake gettext libtool automake autoconf texinfo ninja git

cd /path/to/OrcaSlicer-main
chmod +x build_release_macos.sh scripts/*.sh 2>/dev/null
./build_release_macos.sh -a x86_64 -t 10.15
./scripts/sign_and_package.sh x86_64
```

装好以后建议执行：

```bash
xattr -dr com.apple.quarantine "/Applications/Snapmaker Orca.app"
rm -rf ~/Library/Application\ Support/Snapmaker_Orca/web/flutter_web
```

如果以前装过，第一次打开被拦，请右键 App → 打开。

## 打开后请确认

1. 首页能看到正常内容，不再是纯白或一直转圈
2. 设备页同样正常
3. 如仍异常，把下面目录里的日志发给我：

```text
~/Library/Application Support/Snapmaker_Orca/log/
```
