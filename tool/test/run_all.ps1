<#
.SYNOPSIS
    一键跑完全部门禁 + 设备级用例（默认 Windows 与 Android 都跑）。

.DESCRIPTION
    顺序与 `docs/dev/testing.md` §7 的 CI 一致（先代码生成，再快后慢）；
    **命令本体不在本脚本里另立一份**，逐字对应 `AGENTS.md` §4 的命令清单。

    设备级部分由 `run_windows.ps1` 与 `run_android.ps1` 承担，可用开关跳过。

.EXAMPLE
    pwsh -File tool/test/run_all.ps1                    # 全量
    pwsh -File tool/test/run_all.ps1 -SkipAndroid       # 只跑 Windows
    pwsh -File tool/test/run_all.ps1 -SkipDeviceTests   # 只跑主机侧门禁（CI 等价）
#>
[CmdletBinding()]
param(
    [switch]$SkipDeviceTests,
    [switch]$SkipWindows,
    [switch]$SkipAndroid,
    [string]$AvdName = 'Medium_Phone',
    [switch]$Headless,
    [switch]$KeepEmulator
)

. "$PSScriptRoot/common.ps1"

Assert-FlutterOnPath
Push-Location $RepoRoot
try {
    Invoke-Checked -Label 'flutter pub get' -Command @('flutter', 'pub', 'get')
    Invoke-Checked -Label 'dart run build_runner build' -Command @('dart', 'run', 'build_runner', 'build')
    Invoke-Checked -Label '生成物与源码同步（git diff --exit-code）' -Command @(
        'git', 'diff', '--exit-code', '--', '**/*.g.dart', '**/*.freezed.dart', '**/*.gr.dart'
    )
    Invoke-Checked -Label 'dart format --set-exit-if-changed .' -Command @('dart', 'format', '--set-exit-if-changed', '.')
    Invoke-Checked -Label 'flutter analyze' -Command @('flutter', 'analyze')
    Invoke-Checked -Label 'flutter test --coverage' -Command @('flutter', 'test', '--coverage')
    Invoke-Checked -Label '覆盖率门禁 tool/check_coverage.dart' -Command @('dart', 'run', 'tool/check_coverage.dart')

    if ($SkipDeviceTests) {
        Write-Host '==> 按参数跳过设备级用例' -ForegroundColor Yellow
        return
    }

    if (-not $SkipWindows) {
        & (Join-Path $PSScriptRoot 'run_windows.ps1')
    }
    if (-not $SkipAndroid) {
        & (Join-Path $PSScriptRoot 'run_android.ps1') -AvdName $AvdName -Headless:$Headless -KeepEmulator:$KeepEmulator
    }
}
finally {
    Pop-Location
}
