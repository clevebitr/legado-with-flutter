<#
.SYNOPSIS
    在 Android 模拟器上运行 integration_test/ 下的设备级用例。

.DESCRIPTION
    流程：探测已连接设备 → 没有则启动指定 AVD（脱离当前进程树，原因见 common.ps1 的
    `Start-AndroidEmulator`）→ 等 `sys.boot_completed` → 断言设备仍在线 → 逐文件运行
    `flutter test <file> -d <serial>` → 若模拟器是本脚本启动的，默认用完就关。

    与 Android Studio 的手工操作相比，本脚本的价值是「一条命令可重复」：
    本项目的 minSdk 26 与原生 SQLite 链路只有在真实 Android 运行时上才会被真正执行
    （`docs/dev/platform.md` §1、§6 的 Android 验收清单仍由人工确认，脚本只保证自动化用例）。

    模拟器日志写入 `build/test-artifacts/android-emulator-<avd>.log[.err]`。

.EXAMPLE
    pwsh -File tool/test/run_android.ps1
    pwsh -File tool/test/run_android.ps1 -AvdName Pixel_7_API_36 -KeepEmulator
    pwsh -File tool/test/run_android.ps1 -Headless -BootTimeoutSeconds 600
#>
[CmdletBinding()]
param(
    [string]$AvdName = 'Medium_Phone',
    [int]$BootTimeoutSeconds = 300,
    [switch]$Headless,
    [switch]$KeepEmulator
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/common.ps1"

Assert-FlutterOnPath

Push-Location $RepoRoot
try {
    $serial = Get-ConnectedAndroidSerial
    $emulatorLogPath = $null

    if ($null -eq $serial) {
        $emulatorLogPath = Start-AndroidEmulator -AvdName $AvdName -Headless:$Headless
    }
    else {
        Write-Host "==> 复用已连接的 Android 设备：$serial" -ForegroundColor Cyan
    }

    try {
        $bootArguments = @{ TimeoutSeconds = $BootTimeoutSeconds }
        if ($null -ne $emulatorLogPath) {
            $bootArguments['LogPath'] = $emulatorLogPath
            $bootArguments['FailFastWhenEmulatorExits'] = $true
        }
        $serial = Wait-ForAndroidBoot @bootArguments

        $onlineArguments = @{ Serial = $serial }
        if ($null -ne $emulatorLogPath) {
            $onlineArguments['LogPath'] = $emulatorLogPath
        }
        Assert-AndroidDeviceOnline @onlineArguments

        Invoke-Checked -Label 'flutter pub get' -Command @('flutter', 'pub', 'get')
        Invoke-IntegrationTests -DeviceId $serial
    }
    finally {
        # 只关本脚本启动的模拟器；复用已有设备时不擅自关掉别人的环境。
        if ($null -ne $emulatorLogPath -and -not $KeepEmulator -and $null -ne $serial) {
            Write-Host "==> 关闭模拟器 $serial" -ForegroundColor Cyan
            & (Get-AdbPath) -s $serial emu kill 2>$null | Out-Null
        }
        if ($null -ne $emulatorLogPath) {
            Write-Host "    模拟器日志：$emulatorLogPath" -ForegroundColor DarkGray
        }
    }
}
finally {
    Pop-Location
}
