# Flutter Android 设备无法启动调试

## 1. 问题现象

启动 Flutter Android 调试设备时，无线真机和 Android 模拟器都无法正常使用。

控制台出现类似日志：

```text
[WARN] Flutter assets will be downloaded from https://storage.flutter-io.cn. Make sure you trust this source!
Device daemon started.
[ERR] Error 1 retrieving device properties for PLQ110:
[ERR] adb.exe: device 'adb-3B15AR00E0P00000-bugK5n' not found

[ERR] The Android emulator exited with code 1 during startup
```

`flutter devices -v` 中可能只能看到 Windows 和 Chrome，同时提示模拟器离线：

```text
Device emulator-5554 is offline.
```

`adb devices -l` 中可能出现：

```text
emulator-5554          offline
```

或者无线调试设备名异常：

```text
adb-3B15AR00E0P00000-bugK5n (2)._adb-tls-connect._tcp device product:PLQ110 model:PLQ110
```

## 2. 根本原因

这次问题由两个状态叠加导致。

### 2.1 模拟器残留为 offline

Android 模拟器进程仍在运行，但 ADB 只识别到 `emulator-5554 offline`。这种状态下 Flutter 不会把它当作可调试 Android 设备。

常见原因：

- 模拟器启动或关闭过程中卡住。
- ADB server 状态异常。
- 上一次调试会话未正常退出。

### 2.2 无线调试 mDNS 设备名重复

`adb mdns services` 发现同一台手机暴露了两个无线调试服务：

```text
adb-3B15AR00E0P00000-bugK5n (2)  _adb-tls-connect._tcp  192.168.100.104:32919
adb-3B15AR00E0P00000-bugK5n      _adb-tls-connect._tcp  192.168.100.104:37611
```

其中带 `(2)` 的服务名包含空格。Flutter 后续调用 ADB 时可能把设备 ID 截成：

```text
adb-3B15AR00E0P00000-bugK5n
```

但 ADB 当前实际设备名是：

```text
adb-3B15AR00E0P00000-bugK5n (2)._adb-tls-connect._tcp
```

因此出现：

```text
adb.exe: device 'adb-3B15AR00E0P00000-bugK5n' not found
```

## 3. 排查命令

先确认 Flutter 和 ADB 分别看到什么设备：

```powershell
flutter devices -v
adb devices -l
flutter doctor -v
```

查看可用模拟器：

```powershell
flutter emulators
```

如果 `emulator` 命令不在 PATH 中，可以使用 Android SDK 下的完整路径：

```powershell
& 'D:\soft\Android\sdk\emulator\emulator.exe' -list-avds
```

查看无线调试 mDNS 服务：

```powershell
adb mdns services
```

查看是否存在残留模拟器进程：

```powershell
Get-Process | Where-Object { $_.ProcessName -match 'adb|emulator|qemu' } | Select-Object ProcessName,Id,Path
```

## 4. 解决步骤

### 4.1 恢复模拟器调试

先重启 ADB：

```powershell
adb kill-server
adb start-server
adb devices -l
```

如果模拟器仍然是 `offline`，结束残留模拟器进程：

```powershell
Get-Process | Where-Object { $_.ProcessName -match 'emulator|qemu-system' } | Stop-Process -Force
```

重新启动 AVD：

```powershell
flutter emulators --launch Pixel_9
```

等待 20 秒左右，再确认状态：

```powershell
adb devices -l
flutter devices
```

恢复正常后应能看到类似：

```text
sdk gphone16k x86 64 (mobile) • emulator-5554 • android-x64 • Android 17 (API 37) (emulator)
```

运行到模拟器：

```powershell
flutter run -d emulator-5554
```

### 4.2 恢复无线真机调试

无线调试不要依赖异常的 mDNS 名称，改用 `IP:端口` 直连。

先查看当前无线调试服务：

```powershell
adb mdns services
```

找到手机对应的 `IP:端口`，例如：

```text
192.168.100.104:32919
```

断开旧连接并直连：

```powershell
adb disconnect
adb connect 192.168.100.104:32919
adb devices -l
flutter devices
```

恢复正常后应能看到类似：

```text
PLQ110 (mobile) • 192.168.100.104:32919 • android-arm64 • Android 16 (API 36)
```

运行到真机：

```powershell
flutter run -d 192.168.100.104:32919
```

## 5. 注意事项

- Android 无线调试端口会变化，不能长期固定使用旧端口。
- 如果 `adb connect` 返回 `由于目标计算机积极拒绝，无法连接。 (10061)`，通常表示该端口已经失效，需要在手机“无线调试”页面查看新的端口，必要时重新配对。
- 如果 `adb devices -l` 出现 `offline`，优先重启 ADB；仍不恢复时再关闭残留模拟器进程并重启 AVD。
- 如果 `adb mdns services` 里出现带 `(2)` 的重复无线调试服务，优先使用 `IP:端口` 连接，避免 Flutter 解析设备名失败。

## 6. 本次最终状态

本次处理后，`flutter devices` 能同时识别真机和模拟器：

```text
PLQ110 (mobile)               • 192.168.100.104:32919 • android-arm64 • Android 16 (API 36)
sdk gphone16k x86 64 (mobile) • emulator-5554         • android-x64   • Android 17 (API 37) (emulator)
```
