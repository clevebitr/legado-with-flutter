<#
.SYNOPSIS
    在 Windows 桌面设备上运行 integration_test/ 下的设备级用例。

.DESCRIPTION
    覆盖宿主 VM 无法验证的部分：真实平台通道（`path_provider`、`dynamic_color`）、
    原生 SQLite + 后台 isolate 的文件型数据库。

    前置条件：系统「开发者模式」已开启（`docs/dev/platform.md` §1.2 说明原因）。

.EXAMPLE
    pwsh -File tool/test/run_windows.ps1
    pwsh -File tool/test/run_windows.ps1 -DeviceId windows-x64
#>
[CmdletBinding()]
param(
    [string]$DeviceId = 'windows'
)

. "$PSScriptRoot/common.ps1"

Assert-FlutterOnPath
Assert-DeveloperMode

Push-Location $RepoRoot
try {
    Invoke-IntegrationTests -DeviceId $DeviceId
}
finally {
    Pop-Location
}
