<#
.SYNOPSIS
    主机侧测试：单元/Widget 测试 + 覆盖率门禁（不需要设备）。

.DESCRIPTION
    `flutter test --coverage` 跑在宿主 Dart VM 上（平台通道是假的），随后由
    `tool/check_coverage.dart` 判定分层阈值与「未测量源文件」。命令本体见 `AGENTS.md` §4；
    设备级用例另见 `tool/test/run_windows.ps1` 与 `tool/test/run_android.ps1`。

.EXAMPLE
    pwsh -File tool/test/run_unit.ps1
    pwsh -File tool/test/run_unit.ps1 -SkipCoverage   # 只跑测试，不判定覆盖率
#>
[CmdletBinding()]
param(
    [switch]$SkipCoverage
)

. "$PSScriptRoot/common.ps1"

Assert-FlutterOnPath
Push-Location $RepoRoot
try {
    Invoke-Checked -Label 'flutter test --coverage' -Command @('flutter', 'test', '--coverage')
    if (-not $SkipCoverage) {
        Invoke-Checked -Label '覆盖率门禁 tool/check_coverage.dart' -Command @('dart', 'run', 'tool/check_coverage.dart')
    }
}
finally {
    Pop-Location
}
