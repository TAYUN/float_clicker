#!/usr/bin/env python3
"""Float Clicker project verification MCP server.

This server intentionally has no third-party dependencies. It implements the
small stdio subset of MCP that Codex needs for tool listing and tool calls.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Callable


SERVER_NAME = "float-clicker-verify"
SERVER_VERSION = "0.1.0"
PROTOCOL_VERSION = "2024-11-05"
REPO_ROOT = Path(__file__).resolve().parents[2]
DEBUG_APK = REPO_ROOT / "build" / "app" / "outputs" / "flutter-apk" / "app-debug.apk"
LOG_DIR = REPO_ROOT / "build" / "float_clicker_verify_mcp_logs"


@dataclass(frozen=True)
class CommandSpec:
    name: str
    command: str
    timeout_seconds: int
    parser: Callable[[subprocess.CompletedProcess[str], float], dict[str, Any]]


def _tail(text: str, max_chars: int = 6000) -> str:
    if len(text) <= max_chars:
        return text
    return text[-max_chars:]


def _safe_log_name(name: str) -> str:
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    return f"{timestamp}-{re.sub(r'[^a-zA-Z0-9_.-]+', '_', name)}"


def _write_logs(name: str, stdout: str, stderr: str) -> dict[str, str]:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    base = LOG_DIR / _safe_log_name(name)
    stdout_path = base.with_suffix(".stdout.log")
    stderr_path = base.with_suffix(".stderr.log")
    combined_path = base.with_suffix(".combined.log")
    stdout_path.write_text(stdout, encoding="utf-8", errors="replace")
    stderr_path.write_text(stderr, encoding="utf-8", errors="replace")
    combined_path.write_text(
        f"$ stdout\n{stdout}\n\n$ stderr\n{stderr}",
        encoding="utf-8",
        errors="replace",
    )
    return {
        "stdoutPath": str(stdout_path),
        "stderrPath": str(stderr_path),
        "logPath": str(combined_path),
    }


def _run_command(spec: CommandSpec) -> dict[str, Any]:
    started = time.monotonic()
    try:
        completed = subprocess.run(
            spec.command,
            cwd=REPO_ROOT,
            shell=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            capture_output=True,
            timeout=spec.timeout_seconds,
        )
        duration_ms = round((time.monotonic() - started) * 1000)
        result = spec.parser(completed, duration_ms)
        result.setdefault("name", spec.name)
        result.setdefault("command", spec.command)
        result.setdefault("exitCode", completed.returncode)
        result.setdefault("durationMs", duration_ms)
        result.setdefault("stdoutTail", _tail(completed.stdout))
        result.setdefault("stderrTail", _tail(completed.stderr))
        result.update(_write_logs(spec.name, completed.stdout, completed.stderr))
        result.setdefault("success", completed.returncode == 0)
        if not result["success"]:
            result.setdefault("errorCode", f"{spec.name}_failed")
        return result
    except subprocess.TimeoutExpired as error:
        stdout = error.stdout or ""
        stderr = error.stderr or ""
        if isinstance(stdout, bytes):
            stdout = stdout.decode("utf-8", errors="replace")
        if isinstance(stderr, bytes):
            stderr = stderr.decode("utf-8", errors="replace")
        log_paths = _write_logs(spec.name, stdout, stderr)
        return {
            "name": spec.name,
            "command": spec.command,
            "success": False,
            "exitCode": None,
            "durationMs": round((time.monotonic() - started) * 1000),
            "summary": f"{spec.name} 超时",
            "stdoutTail": _tail(stdout),
            "stderrTail": _tail(stderr),
            "errorCode": "timeout",
            **log_paths,
        }


def _parse_analyze(completed: subprocess.CompletedProcess[str], duration_ms: float) -> dict[str, Any]:
    output = f"{completed.stdout}\n{completed.stderr}"
    success = completed.returncode == 0 and "No issues found" in output
    return {
        "success": success,
        "summary": "flutter analyze 通过" if success else "flutter analyze 失败",
        "errorCode": None if success else "flutter_analyze_failed",
    }


def _parse_test(completed: subprocess.CompletedProcess[str], duration_ms: float) -> dict[str, Any]:
    output = f"{completed.stdout}\n{completed.stderr}"
    match = re.search(r"\+(\d+):\s+All tests passed!", output)
    test_count = int(match.group(1)) if match else None
    success = completed.returncode == 0 and match is not None
    summary = f"{test_count} 个测试通过" if success else "flutter test 失败"
    return {
        "success": success,
        "testCount": test_count,
        "summary": summary,
        "errorCode": None if success else "flutter_test_failed",
    }


def _parse_build(completed: subprocess.CompletedProcess[str], duration_ms: float) -> dict[str, Any]:
    output = f"{completed.stdout}\n{completed.stderr}"
    success = completed.returncode == 0 and "Built build" in output
    return {
        "success": success,
        "apkPath": str(DEBUG_APK),
        "summary": "debug APK 构建成功" if success else "debug APK 构建失败",
        "errorCode": None if success else "debug_apk_build_failed",
    }


def _parse_install(completed: subprocess.CompletedProcess[str], duration_ms: float) -> dict[str, Any]:
    output = f"{completed.stdout}\n{completed.stderr}"
    success = completed.returncode == 0 and re.search(r"(^|\n)Success(\n|$)", output) is not None
    return {
        "success": success,
        "apkPath": str(DEBUG_APK),
        "summary": "debug APK 安装成功" if success else "debug APK 安装失败",
        "errorCode": None if success else "adb_install_failed",
    }


def _parse_adb_devices(completed: subprocess.CompletedProcess[str], duration_ms: float) -> dict[str, Any]:
    devices = []
    for line in completed.stdout.splitlines()[1:]:
        parts = line.split()
        if len(parts) < 2:
            continue
        devices.append({"serial": parts[0], "state": parts[1]})
    online_devices = [device for device in devices if device["state"] == "device"]
    success = completed.returncode == 0 and bool(online_devices)
    return {
        "success": success,
        "devices": devices,
        "onlineDevices": online_devices,
        "summary": f"检测到 {len(online_devices)} 台在线设备" if success else "未检测到在线 adb 设备",
        "errorCode": None if success else "adb_no_device",
    }


def _parse_git_diff_check(completed: subprocess.CompletedProcess[str], duration_ms: float) -> dict[str, Any]:
    success = completed.returncode == 0
    return {
        "success": success,
        "summary": "git diff --check 通过" if success else "git diff --check 发现空白问题",
        "errorCode": None if success else "git_diff_check_failed",
    }


def _parse_dart_format(completed: subprocess.CompletedProcess[str], duration_ms: float) -> dict[str, Any]:
    success = completed.returncode == 0
    changed_match = re.search(r"Formatted\s+\d+\s+files?\s+\((\d+)\s+changed\)", completed.stdout)
    changed_count = int(changed_match.group(1)) if changed_match else None
    return {
        "success": success,
        "changedCount": changed_count,
        "summary": "dart format 通过" if success else "dart format 失败",
        "errorCode": None if success else "dart_format_failed",
    }


COMMANDS: dict[str, CommandSpec] = {
    "flutter_analyze": CommandSpec(
        name="flutter_analyze",
        command="flutter analyze",
        timeout_seconds=300,
        parser=_parse_analyze,
    ),
    "flutter_test": CommandSpec(
        name="flutter_test",
        command="flutter test",
        timeout_seconds=600,
        parser=_parse_test,
    ),
    "flutter_build_debug_apk": CommandSpec(
        name="flutter_build_debug_apk",
        command="flutter build apk --debug",
        timeout_seconds=900,
        parser=_parse_build,
    ),
    "adb_install_debug_apk": CommandSpec(
        name="adb_install_debug_apk",
        command=f'adb install -r "{DEBUG_APK}"',
        timeout_seconds=300,
        parser=_parse_install,
    ),
    "adb_devices": CommandSpec(
        name="adb_devices",
        command="adb devices",
        timeout_seconds=60,
        parser=_parse_adb_devices,
    ),
    "git_diff_check": CommandSpec(
        name="git_diff_check",
        command="git diff --check",
        timeout_seconds=120,
        parser=_parse_git_diff_check,
    ),
}


def _dart_format_spec(paths: list[str]) -> CommandSpec:
    quoted_paths = " ".join(f'"{path}"' for path in paths)
    return CommandSpec(
        name="dart_format",
        command=f"dart format {quoted_paths}",
        timeout_seconds=300,
        parser=_parse_dart_format,
    )


def _tool_schema(name: str, description: str, properties: dict[str, Any] | None = None) -> dict[str, Any]:
    return {
        "name": name,
        "description": description,
        "inputSchema": {
            "type": "object",
            "properties": properties or {},
            "additionalProperties": False,
        },
    }


def _tools() -> list[dict[str, Any]]:
    return [
        _tool_schema(
            "dart_format",
            "Run dart format. This may modify files, so use it only when formatting is intended.",
            {
                "paths": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Paths to format. Defaults to lib and test.",
                    "default": ["lib", "test"],
                }
            },
        ),
        _tool_schema("flutter_analyze", "Run flutter analyze for Float Clicker."),
        _tool_schema("flutter_test", "Run flutter test and parse the passed test count."),
        _tool_schema("flutter_build_debug_apk", "Build the Flutter debug APK."),
        _tool_schema("adb_devices", "List adb devices and require at least one online device."),
        _tool_schema("adb_install_debug_apk", "Install the built debug APK to the connected adb device."),
        _tool_schema("git_diff_check", "Run git diff --check to catch whitespace errors."),
        _tool_schema(
            "verify_debug_pipeline",
            "Run optional format, analyze, test, debug APK build, optional adb install, and optional git diff check.",
            {
                "format": {
                    "type": "boolean",
                    "description": "Whether to run dart format before validation. This may modify files.",
                    "default": False,
                },
                "formatPaths": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Paths passed to dart format when format is true.",
                    "default": ["lib", "test"],
                },
                "install": {
                    "type": "boolean",
                    "description": "Whether to install the debug APK after build.",
                    "default": True,
                },
                "diffCheck": {
                    "type": "boolean",
                    "description": "Whether to run git diff --check at the end.",
                    "default": True,
                },
            },
        ),
    ]


def _call_tool(name: str, arguments: dict[str, Any] | None) -> dict[str, Any]:
    arguments = arguments or {}
    if name == "dart_format":
        paths = arguments.get("paths") or ["lib", "test"]
        return _run_command(_dart_format_spec([str(path) for path in paths]))
    if name == "adb_install_debug_apk":
        devices = _run_command(COMMANDS["adb_devices"])
        if not devices["success"]:
            return devices | {
                "name": "adb_install_debug_apk",
                "command": COMMANDS["adb_install_debug_apk"].command,
                "summary": "debug APK 安装失败：未检测到在线 adb 设备",
            }
        install_result = _run_command(COMMANDS["adb_install_debug_apk"])
        install_result["deviceCheck"] = devices
        return install_result
    if name in COMMANDS:
        return _run_command(COMMANDS[name])
    if name == "verify_debug_pipeline":
        should_format = arguments.get("format", False)
        install = arguments.get("install", True)
        diff_check = arguments.get("diffCheck", True)
        format_paths = arguments.get("formatPaths") or ["lib", "test"]
        steps = []
        if should_format:
            step = _run_command(_dart_format_spec([str(path) for path in format_paths]))
            steps.append(step)
            if not step["success"]:
                return _pipeline_result(steps)
        for step_name in ["flutter_analyze", "flutter_test", "flutter_build_debug_apk"]:
            step = _run_command(COMMANDS[step_name])
            steps.append(step)
            if not step["success"]:
                return _pipeline_result(steps)
        if install:
            devices = _run_command(COMMANDS["adb_devices"])
            steps.append(devices)
            if not devices["success"]:
                return _pipeline_result(steps)
            step = _run_command(COMMANDS["adb_install_debug_apk"])
            steps.append(step)
            if not step["success"]:
                return _pipeline_result(steps)
        if diff_check:
            steps.append(_run_command(COMMANDS["git_diff_check"]))
        return _pipeline_result(steps)
    raise ValueError(f"Unknown tool: {name}")


def _pipeline_result(steps: list[dict[str, Any]]) -> dict[str, Any]:
    success = all(step.get("success") for step in steps)
    failed_step = next((step for step in steps if not step.get("success")), None)
    result = {
        "success": success,
        "summary": "debug 验证流水线通过" if success else "debug 验证流水线失败",
        "steps": steps,
    }
    if failed_step is not None:
        result["failedStep"] = failed_step.get("name")
        result["errorCode"] = failed_step.get("errorCode")
    return result


def _response(request_id: Any, result: Any = None, error: dict[str, Any] | None = None) -> dict[str, Any]:
    response: dict[str, Any] = {"jsonrpc": "2.0", "id": request_id}
    if error is not None:
        response["error"] = error
    else:
        response["result"] = result
    return response


def _tool_result(payload: dict[str, Any]) -> dict[str, Any]:
    return {
        "content": [
            {
                "type": "text",
                "text": json.dumps(payload, ensure_ascii=False, indent=2),
            }
        ],
        "isError": not payload.get("success", False),
    }


def _handle(request: dict[str, Any]) -> dict[str, Any] | None:
    method = request.get("method")
    request_id = request.get("id")
    params = request.get("params") or {}

    if method == "initialize":
        return _response(
            request_id,
            {
                "protocolVersion": PROTOCOL_VERSION,
                "capabilities": {"tools": {}},
                "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION},
            },
        )
    if method == "notifications/initialized":
        return None
    if method == "tools/list":
        return _response(request_id, {"tools": _tools()})
    if method == "tools/call":
        try:
            name = params.get("name")
            arguments = params.get("arguments") or {}
            return _response(request_id, _tool_result(_call_tool(name, arguments)))
        except Exception as error:  # noqa: BLE001 - MCP should return structured errors.
            return _response(
                request_id,
                error={
                    "code": -32000,
                    "message": str(error),
                },
            )
    if request_id is None:
        return None
    return _response(
        request_id,
        error={"code": -32601, "message": f"Method not found: {method}"},
    )


def main() -> int:
    for line in sys.stdin:
        if not line.strip():
            continue
        try:
            request = json.loads(line)
            response = _handle(request)
        except Exception as error:  # noqa: BLE001 - keep server alive on malformed input.
            response = _response(
                None,
                error={"code": -32700, "message": f"Parse error: {error}"},
            )
        if response is not None:
            sys.stdout.write(json.dumps(response, ensure_ascii=False) + "\n")
            sys.stdout.flush()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
