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
        同一路径在下一轮启动前会轮转为 `.prev`，不覆盖：失败现场只在**那一轮**的日志里。

        **启动方式：优先「脱离当前进程树」。** 实测现象：当模拟器是本脚本的子进程时，
        它会在 `flutter test` 的 Gradle 构建期间被连带终止，随后 `adb install` 报
        `adb.exe: device 'emulator-5554' not found`；同样的模拟器以脱离方式启动后，
        同一组用例全部通过。因此这里用 WMI（`Win32_Process.Create`）创建一个中间
        powershell 去 `Start-Process` 模拟器：中间进程立即退出，模拟器不再属于本脚本的
        进程树（也不受外层工具可能施加的 job 限制）。
        若 WMI 不可用（权限或服务被禁），回退为普通子进程并给出警告。

        **快照策略：只保证不「读」（`-no-snapshot-load`）。** 快照曾把这批用例的启动从
        ~30 s 降到 ~10 s，但它也是「一测就半小时」的根源：`adb emu kill` 立刻返回，而模拟器
        还要跑十几秒才写完快照（那几十字节的 `ram.bin` / `snapshot.pb` 才是关键）；脚本、
        外层工具或手工 Ctrl-C 在这个窗口里退出，就留下**一份被截断的快照**，而
        `config.ini` 的 `fastboot.forceFastBoot=yes` 会让之后每一轮都加载它——表现为
        「加载成功但 guest 卡死、adbd 永远 `offline`、干等到超时」。冷启动一轮总共 ~70 s，
        快照一轮 ~52 s：拿回这 ~20 s 不值这个不确定性。

        **写入防不住，也不需要防。** 实测这版模拟器即使给了 `-no-snapshot-save`（并且 AVD 的
        `quickbootChoice.ini` 里 `saveOnExit = false`）仍会在退出时写下
        `snapshots/default_boot`（4 GB 的 `ram.img` + 几十字节的元数据）。所以本脚本的策略是
        **只保证不读**：磁盘上那份东西是截断的还是完整的，对回归已经无所谓，也不会阻塞
        下一轮（想省空间可手工删，本脚本不管）。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$AvdName,
        [switch]$Headless,
        [switch]$WipeData
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

    # 上一轮日志先轮转：`-RedirectStandardOutput` 是**截断**写，不转的话失败现场（模拟器
    # 自己的 boot 检查、`device offline` 时间线）会被下一轮抹掉——实测踩到过。
    # 转不动（上一轮进程还没完全退出、文件仍被占用）**不当作失败**：模拟器接下来会截断它。
    foreach ($rotating in @($logPath, $errorLogPath)) {
        if (-not (Test-Path $rotating)) {
            continue
        }
        try {
            Move-Item -Path $rotating -Destination "$rotating.prev" -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "日志轮转失败（$rotating）：$($_.Exception.Message)。继续运行，本轮会截断该日志。"
        }
    }

    $arguments = @('-avd', $AvdName, '-no-boot-anim')
    # `-crash-report-mode disabled`：实测本机在模拟器崩溃过一次后，每次启动都会弹出
    # crash 上报同意对话框（"Showing crashdialog to get consent."）并**阻塞开机**，
    # 无界面运行时永远起不来。关掉上报消除这个不确定性；模拟器自己的日志仍会写入文件。
    $arguments += @('-crash-report-mode', 'disabled')
    # 快照只关「读」：写入这版模拟器防不住（见上面的快照策略段），但**不读**是可靠性的关键。
    $arguments += @('-no-snapshot-load', '-no-snapshot-save')
    if ($Headless) {
        # `-no-window`：无界面运行，适合没有桌面会话或需要稳定复现的场景。
        $arguments += '-no-window'
    }
    if ($WipeData) {
        # 真正的「新环境」：重置 userdata（代价是首次开机要重新初始化，比普通冷启动慢）。
        $arguments += '-wipe-data'
        Write-Host '    -WipeData：本次重置 AVD 的 userdata（完整首次开机，较慢）' -ForegroundColor Yellow
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

function Get-AndroidEmulatorSnapshotPath {
    <#
    .SYNOPSIS
        返回指定 AVD 的 `default_boot` 快照目录，不存在时返回 $null。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$AvdName
    )

    $root = $env:ANDROID_AVD_HOME
    if ([string]::IsNullOrWhiteSpace($root)) {
        $root = Join-Path $env:USERPROFILE '.android\avd'
    }
    $snapshot = Join-Path (Join-Path $root "$AvdName.avd") 'snapshots\default_boot'
    if (-not (Test-Path $snapshot)) {
        return $null
    }

    return (Resolve-Path $snapshot).Path
}

function Remove-AndroidEmulatorSnapshot {
    <#
    .SYNOPSIS
        删掉 AVD 的 `default_boot` 快照（本轮跑完的清理动作）。

    .DESCRIPTION
        模拟器每次退出都会写一份（~4 GB 的 `ram.img` + 几十字节元数据），而本脚本从来不读它；
        不删就是每轮白写 4 GB、且把可能的截断状态一直留在磁盘上。
        **必须在 `Wait-ForAndroidEmulatorExit` 之后调**，否则模拟器还在写。
        删不掉只 warning：清理失败不该把一次已经跑完的回归弄成失败。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$AvdName
    )

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $snapshot = Get-AndroidEmulatorSnapshotPath -AvdName $AvdName
        if ($null -eq $snapshot) {
            return
        }
        try {
            Remove-Item -Path $snapshot -Recurse -Force -ErrorAction Stop
            Write-Host "    已清理本轮快照：$snapshot" -ForegroundColor DarkGray
            return
        }
        catch {
            if ($attempt -eq 3) {
                Write-Warning "清理快照失败（$snapshot）：$($_.Exception.Message)。不影响本轮结果（本脚本从不读快照）。"
                return
            }
            Start-Sleep -Seconds 3
        }
    }
}

function Get-AndroidEmulatorProcessIds {
    <#
    .SYNOPSIS
        属于指定 AVD 的模拟器进程：启动器 `emulator.exe` 与它的 `qemu-system-*` 子进程，
        两者的命令行里都带 `-avd <名字>`（实测核对过），所以不会误伤别的模拟器。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$AvdName
    )

    $ids = @()
    $candidates = Get-CimInstance Win32_Process | Where-Object {
        $_.Name -eq 'emulator.exe' -or $_.Name -like 'qemu-system*'
    }
    foreach ($candidate in $candidates) {
        if ($candidate.CommandLine -and $candidate.CommandLine -like "*-avd $AvdName*") {
            $ids += $candidate.ProcessId
        }
    }
    return $ids
}

function Wait-ForAndroidEmulatorExit {
    <#
    .SYNOPSIS
        等指定 AVD 的模拟器进程全部退出。

    .DESCRIPTION
        等的是**进程**（命令行带 `-avd <名字>` 的 `emulator.exe` / `qemu-system-*`），
        而不是 `adb devices` 里的条目：条目比进程先消失，而进程还活着时下一轮的模拟器
        启动会撞上它（实测：日志文件被占、新模拟器开机中途自己退出）。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$AvdName,
        [int]$TimeoutSeconds = 90
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (@(Get-AndroidEmulatorProcessIds -AvdName $AvdName).Count -eq 0) {
            return $true
        }
        Start-Sleep -Seconds 2
    }

    $ids = @(Get-AndroidEmulatorProcessIds -AvdName $AvdName)
    if ($ids.Count -gt 0) {
        Write-Warning "模拟器进程未在 $TimeoutSeconds 秒内退出（pid: $($ids -join ', ')）。"
        return $false
    }
    return $true
}

function Stop-AndroidEmulator {
    <#
    .SYNOPSIS
        尽力关掉模拟器（缺省挑第一个 `emulator-*`，含 `offline` 僵尸），并等它真正退出。

    .DESCRIPTION
        `run_android.ps1` 的 `finally` 原先只在 `Wait-ForAndroidBoot` **成功返回**后才关模拟器
        （`$serial` 那时才被赋值），于是「开机超时」恰好是唯一不关它的路径：留下一个
        `offline` 的僵尸占着 AVD 锁与 5554 端口，下一轮启动直接撞上。这里把判据交给调用方
        （「是不是本脚本启动的」），并在这里兼容 `$Serial` 为空与设备处于 `offline` 两种情形。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$AvdName,
        [string]$Serial,
        [switch]$CleanSnapshot,
        [int]$TimeoutSeconds = 90
    )

    $adb = Get-AdbPath
    if ([string]::IsNullOrWhiteSpace($Serial)) {
        # `Get-ConnectedAndroidSerial` 只认 `device` 状态，僵尸是 `offline`，所以另扫一遍。
        foreach ($line in (& $adb devices)) {
            if ($line -match '^(emulator-\d+)\s') {
                $Serial = $Matches[1]
                break
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($Serial)) {
        Write-Host "==> 关闭模拟器 $AvdName（未拿到 serial，按进程收尾）" -ForegroundColor Cyan
    }
    else {
        Write-Host "==> 关闭模拟器 $Serial" -ForegroundColor Cyan
        & $adb -s $Serial emu kill 2>$null | Out-Null
    }

    Wait-ForAndroidEmulatorExit -AvdName $AvdName -TimeoutSeconds $TimeoutSeconds | Out-Null
    if ($CleanSnapshot) {
        Remove-AndroidEmulatorSnapshot -AvdName $AvdName
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

        代价是**每个文件一次构建+安装**（Flutter 对每个测试文件都新建一个
        `IntegrationTestTestDevice`，`flutter_platform.dart:469`），所以 `-FileFilter`
        存在的意义就是：改了引擎/桥这类只在 `js_bridge` 里有覆盖的切片时，别再为另外两个
        文件白付两次构建。合一条 `flutter test integration_test -d <device>` **省不掉**这个
        （仍然是一文件一设备实例），只有 `-FileFilter` 或合并文件能省。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$DeviceId,
        [string]$FileFilter
    )

    $files = Get-IntegrationTestFiles
    if (-not [string]::IsNullOrWhiteSpace($FileFilter)) {
        $files = @($files | Where-Object { (Split-Path -Leaf $_) -like "*$FileFilter*" })
        if ($files.Count -eq 0) {
            throw "integration_test/ 下没有文件名包含 '$FileFilter' 的用例。"
        }
        Write-Host "==> 只跑匹配 '$FileFilter' 的用例文件（$($files.Count) 个）" -ForegroundColor Cyan
    }
    if ($files.Count -eq 0) {
        Write-Host '==> 没有集成测试文件，跳过' -ForegroundColor Yellow
        return
    }

    foreach ($file in $files) {
        $name = Split-Path -Leaf $file
        Invoke-Checked -Label "集成测试 $name（$DeviceId）" -Command @('flutter', 'test', $file, '-d', $DeviceId)
    }
}
