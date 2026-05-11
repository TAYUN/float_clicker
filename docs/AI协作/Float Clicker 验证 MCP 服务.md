# Float Clicker 验证 MCP 服务

## 1. 目的

Float Clicker 开发中经常需要重复执行固定验收命令：

```powershell
flutter analyze
flutter test
flutter build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

这些命令输入稳定、输出格式相对稳定，适合封装为 MCP 服务，供 Codex / AI 在多会话中长期复用。

目标不是简单少敲命令，而是：

- 让 AI 使用固定工具执行项目验收。
- 返回结构化结果，便于自动判断通过、失败和测试数量。
- 统一解析常见错误输出。
- 避免每个新对话重新约定命令和输出格式。

## 2. 服务位置

项目本地 MCP 服务放在：

```text
tools/float_clicker_verify_mcp/server.py
```

说明文档放在：

```text
tools/float_clicker_verify_mcp/README.md
```

服务是 stdio MCP server，不依赖第三方 Python 包。

## 3. 工具列表

- `dart_format`：运行 `dart format`，默认格式化 `lib` 和 `test`，会修改文件。
- `flutter_analyze`：运行 `flutter analyze`。
- `flutter_test`：运行 `flutter test`，解析通过测试数量。
- `flutter_build_debug_apk`：运行 `flutter build apk --debug`。
- `adb_devices`：运行 `adb devices`，要求至少有 1 台在线设备，并返回在线设备的品牌、型号和 Android 版本。
- `adb_install_debug_apk`：安装 `build\app\outputs\flutter-apk\app-debug.apk`。
- `git_diff_check`：运行 `git diff --check`。
- `verify_debug_pipeline`：按顺序执行可选 format、analyze、test、build、可选 install 和可选 diff check。

## 4. Codex 配置示例

项目级配置已经写入：

```text
.codex/config.toml
```

内容为：

```toml
[mcp_servers.float_clicker_verify]
command = "python"
# 使用项目根目录作为工作目录，避免脚本内相对路径依赖当前会话启动位置。
cwd = "D:\\code-my\\float_clicker\\float_clicker"
args = ["tools/float_clicker_verify_mcp/server.py"]
```

如果在其他 Codex 环境中需要手动配置，也可以使用绝对路径形式：

```toml
[mcp_servers.float_clicker_verify]
command = "python"
args = ["D:\\code-my\\float_clicker\\float_clicker\\tools\\float_clicker_verify_mcp\\server.py"]
```

配置完成后，新对话中可以直接要求：

```text
使用 Float Clicker verify MCP 跑 debug 验证流水线。
```

AI 应优先调用 MCP 工具，而不是手写 shell 命令。

## 5. 输出格式

工具返回 JSON 文本。示例：

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
      "summary": "55 个测试通过"
    }
  ]
}
```

`adb_devices` 会在 `adb devices` 的 serial 基础上补充设备识别字段，方便 AI 判断当前连接的是哪台真机：

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

失败时保留：

- `name`
- `command`
- `exitCode`
- `summary`
- `stdoutTail`
- `stderrTail`
- `errorCode`
- `logPath`
- `stdoutPath`
- `stderrPath`

这样 AI 可以直接定位是哪一步失败，而不是重新翻完整控制台输出。

常见错误分类：

- `dart_format_failed`
- `flutter_analyze_failed`
- `flutter_test_failed`
- `debug_apk_build_failed`
- `adb_no_device`
- `adb_install_failed`
- `git_diff_check_failed`
- `timeout`

完整日志默认写入：

```text
build/float_clicker_verify_mcp_logs/
```

JSON 里只保留 tail，AI 如需完整输出可继续读取 `logPath`。

## 6. 流水线参数

`verify_debug_pipeline` 支持：

- `format`：默认 `false`。设为 `true` 时先执行 `dart format`，会修改文件。
- `formatPaths`：默认 `["lib", "test"]`。
- `install`：默认 `true`。设为 `false` 时只跑到 debug APK 构建。
- `diffCheck`：默认 `true`。末尾执行 `git diff --check`。

建议：

- 常规开发后验证：`{"format": false, "install": true, "diffCheck": true}`。
- 只想快速跑 CI 类检查：`{"install": false}`。
- 需要自动格式化时，明确传 `{"format": true}`。

## 7. 使用边界

适合：

- 常规自动化验收。
- debug 包构建和安装。
- 在不同 Codex 对话之间复用固定验证流程。
- 让 AI 输出一致的验证摘要。

不适合：

- 真机交互验收，例如点击悬浮窗、横竖屏拖动、系统权限开关。
- 需要人工判断 UI 是否符合预期的场景。
- 需要动态排查日志、截图或性能问题的专项调试。

真机专项仍应写入 `docs/开发计划/Codex协作记录/` 或 `docs/调试问题/`。

## 8. 维护建议

- 如果测试数量变化，只需要让 MCP 解析实际输出，不要在文档中硬编码为固定数量。
- 如果新增 release 构建、日志采集或设备检查，可以继续扩展 MCP 工具。
- MCP 服务代码应和项目一起提交，保证新会话、新机器和新分支都能复用。
- 不建议在服务里自动提交 git、切分支或修改代码；验证工具应保持只执行验收命令。
- 涉及修改文件的工具必须默认关闭或显式传参，例如 `format=true`。
