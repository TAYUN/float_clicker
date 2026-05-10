# Float Clicker Verify MCP

项目本地 MCP 服务，用于让 Codex/AI 以结构化方式执行 Float Clicker 固定验收命令。

## 提供的工具

- `dart_format`：执行 `dart format`，默认格式化 `lib` 和 `test`，会修改文件。
- `flutter_analyze`：执行 `flutter analyze`。
- `flutter_test`：执行 `flutter test`，解析通过测试数量。
- `flutter_build_debug_apk`：执行 `flutter build apk --debug`。
- `adb_devices`：执行 `adb devices`，要求至少有 1 台在线设备，并返回在线设备的品牌、型号和 Android 版本。
- `adb_install_debug_apk`：执行 `adb install -r build\app\outputs\flutter-apk\app-debug.apk`。
- `git_diff_check`：执行 `git diff --check`。
- `verify_debug_pipeline`：按顺序执行可选 format、analyze、test、debug apk 构建、可选安装和可选 diff check。

## 手动启动

```powershell
python tools\float_clicker_verify_mcp\server.py
```

该服务使用 MCP stdio 协议，通常由 Codex 或其他 MCP 客户端拉起，不需要手动交互。

## Codex 配置示例

把下面配置加入你的 Codex MCP 配置位置后，新对话即可复用这些工具。具体配置文件位置以你当前 Codex 版本为准。

```toml
[mcp_servers.float_clicker_verify]
command = "python"
args = ["D:\\code-my\\float_clicker\\float_clicker\\tools\\float_clicker_verify_mcp\\server.py"]
```

## 输出格式

工具返回 JSON 文本，核心字段：

```json
{
  "success": true,
  "summary": "debug 验证流水线通过",
  "steps": [
    {
      "name": "flutter_test",
      "success": true,
      "exitCode": 0,
      "testCount": 55,
      "summary": "55 个测试通过",
      "logPath": "D:\\code-my\\float_clicker\\float_clicker\\build\\float_clicker_verify_mcp_logs\\...",
      "stdoutTail": "...",
      "stderrTail": "..."
    }
  ]
}
```

失败时会保留命令、退出码、摘要、错误分类、stdout/stderr 尾部和完整日志路径，方便 AI 直接判断下一步。

`adb_devices` 会额外返回设备识别信息，方便区分多台真机：

```json
{
  "success": true,
  "summary": "检测到 1 台在线设备",
  "onlineDevices": [
    {
      "serial": "10.244.122.130:41035",
      "state": "device",
      "manufacturer": "OPPO",
      "brand": "OPPO",
      "model": "示例型号",
      "device": "示例设备代号",
      "androidRelease": "16",
      "sdk": "36",
      "displayName": "OPPO 示例型号 Android 16 (SDK 36) [10.244.122.130:41035]"
    }
  ]
}
```

常见 `errorCode`：

- `dart_format_failed`
- `flutter_analyze_failed`
- `flutter_test_failed`
- `debug_apk_build_failed`
- `adb_no_device`
- `adb_install_failed`
- `git_diff_check_failed`
- `timeout`

## 常用调用

只跑 analyze、test、build 和 diff check，不安装：

```json
{"name":"verify_debug_pipeline","arguments":{"install":false}}
```

需要安装到真机：

```json
{"name":"verify_debug_pipeline","arguments":{"install":true}}
```

需要先格式化再验收：

```json
{"name":"verify_debug_pipeline","arguments":{"format":true,"install":true}}
```

`format` 默认为 `false`，避免 MCP 在未明确要求时修改文件。
