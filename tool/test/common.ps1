<#
.SYNOPSIS
    `tool/test/` 下各脚本的共享工具函数。

.DESCRIPTION
    由其他脚本以 `. "$PSScriptRoot/common.ps1"` 引入，**不要单独执行**。
    这里只放三件公共事：仓库根路径解析、命令执行与失败传播、Android 设备/模拟器辅助。

    规范来源：`AGENTS.md` §4（门禁命令的唯一出处）与 `docs/dev/test-environment.md`
    （本机 Windows/Android 测试环境）。本文件不复制任何门禁命令清单。

.NOTES
    兼容 Windows PowerShell 5.1（不使用 PS7 才有的语法）。
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 中文输出在管道/重定向下也按 UTF-8 写（否则 Windows PowerShell 5.1 会用 ANSI 写，
# `script.ps1 > log.txt` 或 CI 日志里的中文会变成乱码）。
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
}
catch {
    # 少数宿主（如 ISE）不允许改控制台编码：降级为默认编码，不中断测试。
    Write-Verbose "无法设置控制台输出编码：$($_.Exception.Message)"
}

# 仓库根目录：tool/test/ 往上两级。
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

# 测试产物目录（已被 .gitignore 的 build/ 覆盖），用于存放模拟器日志等排错证据。
$ArtifactDir = Join-Path $RepoRoot 'build\test-artifacts'

function Invoke-Checked {
    <#
    .SYNOPSIS
        执行一条命令；非零退出码时抛出，让脚本以非零码结束。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string[]]$Command
    )

    Write-Host "==> $Label" -ForegroundColor Cyan
    $executable = $Command[0]
    $arguments = @()
    if ($Command.Count -gt 1) {
        $arguments = $Command[1..($Command.Count - 1)]
    }

    & $executable @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Label 失败（退出码 $LASTEXITCODE）"
    }
}

function Assert-FlutterOnPath {
    <#
    .SYNOPSIS
        确认 flutter 在 PATH 上，否则给出可操作的错误。
    #>
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        throw 'PATH 上找不到 flutter。请把 Flutter SDK 的 bin 目录加入 PATH，然后重开终端。'
    }
}

function Assert-DeveloperMode {
    <#
    .SYNOPSIS
        Windows 桌面构建的前置条件：系统开发者模式（docs/dev/platform.md §1.2）。

    .DESCRIPTION
        本项目的插件带有原生代码，`flutter build windows` 需要为插件创建符号链接；
        未开启开发者模式时会直接失败并提示 "Building with plugins requires symlink support"。
    #>
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
    $value = $null
    if (Test-Path $key) {
        $value = (Get-ItemProperty -Path $key -Name AllowDevelopmentWithoutDevLicense -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense
    }

    if ($value -ne 1) {
        throw @'
未开启 Windows 开发者模式，`flutter build windows` 会因插件符号链接失败
（docs/dev/platform.md §1.2）。请以管理员身份执行 `start ms-settings:developers`
并打开「开发人员模式」，然后重试。
'@
    }
}

function Get-AndroidSdkPath {
    <#
    .SYNOPSIS
        返回 Android SDK 根目录；依次探测 ANDROID_HOME、ANDROID_SDK_ROOT、默认安装位置。
    #>
    $candidates = @(
        $env:ANDROID_HOME,
        $env:ANDROID_SDK_ROOT,
        (Join-Path $env:LOCALAPPDATA 'Android\sdk')
    )

    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        if (Test-Path (Join-Path $candidate 'platform-tools\adb.exe')) {
            return (Resolve-Path $candidate).Path
        }
    }

    throw '找不到 Android SDK。请设置 ANDROID_HOME，或确认 SDK 装在 %LOCALAPPDATA%\Android\sdk。'
}

function Get-AdbPath {
    <#
    .SYNOPSIS
        返回 adb 的完整路径。
    #>
    return (Join-Path (Get-AndroidSdkPath) 'platform-tools\adb.exe')
}

function Get-EmulatorPath {
    <#
    .SYNOPSIS
        返回 emulator.exe 的完整路径。
    #>
    $emulator = Join-Path (Get-AndroidSdkPath) 'emulator\emulator.exe'
    if (-not (Test-Path $emulator)) {
        throw "找不到 emulator.exe：$emulator。请用 Android Studio 的 SDK Manager 安装 Emulator。"
    }
    return $emulator
}

function Get-ConnectedAndroidSerial {
    <#
    .SYNOPSIS
        返回第一个处于 `device` 状态的 Android 序列号；没有则返回 $null。
    #>
    $adb = Get-AdbPath
    $lines = & $adb devices
    foreach ($line in $lines) {
        if ($line -match '^(\S+)\s+device$') {
            return $Matches[1]
        }
    }
    return $null
}

function Test-AndroidEmulatorProcessRunning {
    <#
    .SYNOPSIS
        判断本机是否还有 Android 模拟器进程（launcher + qemu）。
    #>
    $qemu = @(Get-Process -Name 'qemu-system-*' -ErrorAction SilentlyContinue)
    $launcher = @(Get-Process -Name 'emulator' -ErrorAction SilentlyContinue)
    return ($qemu.Count -gt 0) -or ($launcher.Count -gt 0)
}

function Start-AndroidEmulator {
    <#
    .SYNOPSIS
        启动指定 AVD，返回模拟器日志路径。

    .DESCRIPTION
        模拟器的 stdout/stderr 写入 `build/test-artifacts/android-emulator-<avd>.log[.err]`：
        模拟器一旦崩溃或自行退出，这是唯一的排错证据（`build/` 已被 .gitignore 覆盖）。

        **启动方式：优先「脱离当前进程树」。** 实测现象：当模拟器是本脚本的子进程时，
        它会在 `flutter test` 的 Gradle 构建期间被连带终止，随后 `adb install` 报
        `adb.exe: device 'emulator-5554' not found`；同样的模拟器以脱离方式启动后，
        同一组用例全部通过。因此这里用 WMI（`Win32_Process.Create`）创建一个中间
        powershell 去 `Start-Process` 模拟器：中间进程立即退出，模拟器不再属于本脚本的
        进程树（也不受外层工具可能施加的 job 限制）。
        若 WMI 不可用（权限或服务被禁），回退为普通子进程并给出警告。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$AvdName,
        [switch]$Headless
    )

    $emulator = Get-EmulatorPath
    $available = & $emulator -list-avds
    if ($available -notcontains $AvdName) {
        throw "AVD '$AvdName' 不存在。现有：$($available -join ', ')。可用 Android Studio 的 Device Manager 创建，或用 -AvdName 指定。"
    }

    if (-not (Test-Path $ArtifactDir)) {
        New-Item -ItemType Directory -Path $ArtifactDir -Force | Out-Null
    }
    $logPath = Join-Path $ArtifactDir "android-emulator-$AvdName.log"
    $errorLogPath = "$logPath.err"

    $arguments = @('-avd', $AvdName, '-no-boot-anim')
    # `-crash-report-mode disabled`：实测本机在模拟器崩溃过一次后，每次启动都会弹出
    # crash 上报同意对话框（"Showing crashdialog to get consent."）并**阻塞开机**，
    # 无界面运行时永远起不来。关掉上报消除这个不确定性；模拟器自己的日志仍会写入文件。
    $arguments += @('-crash-report-mode', 'disabled')
    if ($Headless) {
        # `-no-window`：无界面运行，适合没有桌面会话或需要稳定复现的场景。
        $arguments += '-no-window'
    }

    Write-Host "==> 启动 Android 模拟器：$AvdName（日志：$logPath）" -ForegroundColor Cyan

    # 中间进程只做一件事：Start-Process 后立即退出。
    $quotedArguments = ($arguments | ForEach-Object { "'$_'" }) -join ','
    $launcher = "Start-Process -FilePath '$emulator' -ArgumentList @($quotedArguments) " +
        "-RedirectStandardOutput '$logPath' -RedirectStandardError '$errorLogPath'"

    $created = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
        CommandLine = "powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -Command `"$launcher`""
    }

    if ($created.ReturnValue -eq 0) {
        return $logPath
    }

    Write-Warning "WMI 分离启动失败（Win32_Process.Create 返回 $($created.ReturnValue)），回退为子进程启动；若外层环境限制进程树，模拟器可能在构建期间被终止。"
    Start-Process -FilePath $emulator -ArgumentList $arguments -PassThru `
        -RedirectStandardOutput $logPath -RedirectStandardError $errorLogPath | Out-Null

    return $logPath
}

function Wait-ForAndroidBoot {
    <#
    .SYNOPSIS
        等待设备出现并完成开机（sys.boot_completed == 1），返回设备序列号。

    .DESCRIPTION
        `-FailFastWhenEmulatorExits` 用于「模拟器是本脚本启动的」场景：前 20 秒是启动宽限期，
        之后若本机已没有任何模拟器进程，立即报错并指向日志，而不是干等到超时。
    #>
    param(
        [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
        [string]$LogPath,
        [switch]$FailFastWhenEmulatorExits
    )

    $adb = Get-AdbPath
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $gracePeriod = (Get-Date).AddSeconds(20)

    Write-Host "==> 等待 Android 设备启动（最长 $TimeoutSeconds 秒）" -ForegroundColor Cyan
    while ((Get-Date) -lt $deadline) {
        if ($FailFastWhenEmulatorExits -and (Get-Date) -gt $gracePeriod -and
            -not (Test-AndroidEmulatorProcessRunning)) {
            throw "模拟器进程已消失，未能完成开机。模拟器日志：$LogPath"
        }

        $serial = Get-ConnectedAndroidSerial
        if ($null -ne $serial) {
            $booted = (& $adb -s $serial shell getprop sys.boot_completed 2>$null) -join ''
            if ($booted.Trim() -eq '1') {
                Write-Host "    设备就绪：$serial" -ForegroundColor Green
                return $serial
            }
        }
        Start-Sleep -Seconds 2
    }

    throw "等待 Android 设备启动超时（$TimeoutSeconds 秒）。可先手动跑 flutter devices 排查；模拟器日志：$LogPath"
}

function Assert-AndroidDeviceOnline {
    <#
    .SYNOPSIS
        断言设备此刻仍在线，否则给出可操作的错误。

    .DESCRIPTION
        实测遇到过：设备通过 `sys.boot_completed` 检查后，在 Gradle 构建期间掉线，
        随后 `adb install` 报 "device 'emulator-5554' not found"。提前断言能让错误
        落在本脚本上，而不是伪装成 Flutter 的安装失败。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Serial,
        [string]$LogPath
    )

    $adb = Get-AdbPath
    $state = ((& $adb -s $Serial get-state 2>$null) -join '').Trim()
    if ($state -ne 'device') {
        throw "Android 设备 $Serial 不在线（adb get-state = '$state'）。模拟器日志：$LogPath"
    }
}

function Get-IntegrationTestFiles {
    <#
    .SYNOPSIS
        列出 integration_test/ 下的用例文件。
    #>
    $directory = Join-Path $RepoRoot 'integration_test'
    if (-not (Test-Path $directory)) {
        throw "找不到 $directory。设备级用例目录缺失，请先恢复。"
    }
    return @(Get-ChildItem -Path $directory -Filter '*_test.dart' | Sort-Object Name | ForEach-Object { $_.FullName })
}

function Invoke-IntegrationTests {
    <#
    .SYNOPSIS
        在指定设备上逐个用例文件运行 `flutter test`。

    .DESCRIPTION
        **刻意逐文件调用，而不是 `flutter test integration_test -d <device>`：**
        桌面端在同一次 `flutter test` 里跑第二个文件时会二次启动同一个 exe 并失败
        （"Error waiting for a debug connection: The log reader stopped unexpectedly,
        or never started."），逐文件调用是本仓库在 Windows 上实测稳定的方式。
        细节与排错见 docs/dev/test-environment.md §5。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$DeviceId
    )

    $files = Get-IntegrationTestFiles
    if ($files.Count -eq 0) {
        Write-Host '==> 没有集成测试文件，跳过' -ForegroundColor Yellow
        return
    }

    foreach ($file in $files) {
        $name = Split-Path -Leaf $file
        Invoke-Checked -Label "集成测试 $name（$DeviceId）" -Command @('flutter', 'test', $file, '-d', $DeviceId)
    }
}
