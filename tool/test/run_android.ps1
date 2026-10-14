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

    模拟器日志写入 `build/test-artifacts/android-emulator-<avd>.log[.err]`（上一轮在同名的 `.prev`）。

.PARAMETER TestFile
    只跑文件名包含该子串的用例文件（如 `-TestFile js_bridge`）。逐文件运行意味着
    **一文件一次构建+安装**，而多数切片只需 `js_bridge_test.dart`。

.PARAMETER WipeData
    启动前重置 AVD 的 userdata，给一个真正全新的 guest（代价：完整首次开机，比普通冷启动慢）。

.EXAMPLE
    pwsh -File tool/test/run_android.ps1
    pwsh -File tool/test/run_android.ps1 -TestFile js_bridge
    pwsh -File tool/test/run_android.ps1 -AvdName Pixel_7_API_36 -KeepEmulator
    pwsh -File tool/test/run_android.ps1 -Headless -BootTimeoutSeconds 600
    pwsh -File tool/test/run_android.ps1 -WipeData
#>
[CmdletBinding()]
param(
    [string]$AvdName = 'Medium_Phone',
    [int]$BootTimeoutSeconds = 300,
    [switch]$Headless,
    [switch]$KeepEmulator,
    [string]$TestFile,
    [switch]$WipeData
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/common.ps1"

Assert-FlutterOnPath

Push-Location $RepoRoot
$exitCode = 0
try {
    $serial = Get-ConnectedAndroidSerial
    $emulatorLogPath = $null
    # 「模拟器是不是本脚本启动的」——必须在**启动之前**定下，不能靠 `$serial` 后来有没有值。
    $startedEmulator = $false

    if ($null -eq $serial) {
        $emulatorLogPath = Start-AndroidEmulator -AvdName $AvdName -Headless:$Headless -WipeData:$WipeData
        $startedEmulator = $true
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
        $testArguments = @{ DeviceId = $serial }
        if (-not [string]::IsNullOrWhiteSpace($TestFile)) {
            $testArguments['FileFilter'] = $TestFile
        }
        Invoke-IntegrationTests @testArguments
    }
    finally {
        # 只关本脚本启动的模拟器；复用已有设备时不擅自关掉别人的环境。
        # 判据是 `$startedEmulator`：原先用 `$null -ne $serial`，而 `$serial` 只在
        # `Wait-ForAndroidBoot` **成功**后才被赋值——于是「开机超时」恰好是唯一不关模拟器的
        # 路径，留下 `offline` 僵尸占着 AVD 锁，下一轮启动直接撞上。
        if ($startedEmulator -and -not $KeepEmulator) {
            # 跑完就把这一轮写下的快照清掉（本脚本从不读快照，留着只是每轮白写 4 GB）；
            # 清理在「等进程退出」之后做，所以不会跟模拟器的写盘撞上。
            Stop-AndroidEmulator -AvdName $AvdName -Serial $serial -CleanSnapshot
        }
        if ($null -ne $emulatorLogPath) {
            Write-Host "    模拟器日志：$emulatorLogPath（上一轮：$emulatorLogPath.prev）" -ForegroundColor DarkGray
        }
    }
}
catch {
    # 失败路径不再让异常自己往上冒：**实测** `pwsh -File` 在「WMI 启过模拟器 + 抛终止性错误」
    # 之后会打印完异常块却**不退出**（进程无子进程、线程全在 UserRequest，命令因此看起来
    # “一直在跑”）。这里只负责把消息与位置打出来，然后显式 `exit`——退出码语义不变
    # （门禁依旧看到非零），但不再依赖 PowerShell 默认的收尾。
    Write-Host "==> 失败：$($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    $exitCode = 1
}
finally {
    Pop-Location
}
exit $exitCode
