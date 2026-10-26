# ADR-0074 M22-c：备份增强（自动备份、覆盖式恢复、整包加密、WebDAV）

- **状态：** Accepted（2026-10-25，用户裁决四项：四项一次做完含 WebDAV；备份范围维持不含
  Cookie / 缓存 / 校验历史；凭据存系统密钥库；安全副本写「用户选的备份位置，未设置则应用私有目录」）
- **日期：** 2026-10-25
- **关联：** ADR-0073（备份格式与合并恢复）、ADR-0072（`login_info` 明文存库）、ADR-0068（Cookie
  持久化）、C-SEC-1/2/4、C-NET-1、C-DEP-7、`docs/dev/roadmap.md` §3.7

## 背景

ADR-0073 交付了「导出一个 zip / 按自然键合并恢复」的最小闭环，并把五件事登记为未做：
自动备份与保留份数、WebDAV、覆盖式恢复、加密、以及备份范围是否扩到 Cookie。上游的做法是：

| 项 | 上游落点 | 上游行为 |
|---|---|---|
| 自动备份 | `Backup.autoBack()`、`LocalConfig.lastBackup` | 启动时若「距上次 ≥ 1 天」就跑；`onlyLatestBackup` 打开时固定写 `backup.zip`，否则 `backup<date>-<device>.zip` |
| 保留份数 | — | **没有**份数概念，只有 `onlyLatestBackup` 一个开关 |
| 覆盖式恢复 | `Restore.kt` | 按表混合语义（`bookshelf` 计划式新增/更新/删除、`bookGroup`/`homepage*` `replaceAll`、其余 `insert` 吞冲突）；恢复前不写安全副本 |
| 加密 | `BackupAES` | `MD5(本地口令)` 前 16 字节做 AES 密钥，**只**加密 `servers.json` 与 `config.xml` 里的 `webDavPassword` |
| WebDAV | `AppWebDav` + `lib/webdav` | 完整客户端（PROPFIND/PUT/DELETE/…），`mode = local \| webdav \| both`，上传失败只记日志；另有「云端进度覆盖」一条专线 |
| 备份位置 | `Backup.backupPath`（私有目录）+ `backupPath` 偏好 | 压缩中间产物在私有目录，最终文件拷到用户选的 SAF 目录或私有目录 |

## 决策 1 备份位置是一个概念，自动备份 / 安全副本 / 手动导出都走它

- 新增 `BackupLocation`：`appPrivate`（默认，`path_provider` 的应用支持目录下 `backups/`）或
  `folder(path)`（用户经系统目录选择器选的文件夹，路径存 `shared_preferences`）。
- **自动备份**与**恢复前安全副本**只写这个位置；**手动导出**有两条路：「保存到备份位置」（默认动作，
  回执里显示落点）与「另存为…」（系统保存框，ADR-0073 原有行为保留）。
- 目录选择器是新端口 `BackupDirectoryPicker`（`file_selector` 的 `getDirectoryPath`，只给目录不需要
  MIME/扩展名）。路径失效（文件夹被删/权限变化）时回落 `appPrivate` 并在页面明示，**不静默丢备份**。

## 决策 2 自动备份 = 1 天节流 + 保留份数（N=1 即上游的 onlyLatestBackup）

- 触发点：应用启动时（`AppShell` 首帧后）检查一次，不引入后台调度器——上游也是启动时触发，
  后台定时需要 `workmanager` 一类依赖与三端权限，收益不足。
- 节流：`backup.lastAt`（毫秒时间戳）距现在不足 24 小时就跳过；**先写文件再更新时间戳**，写失败下次
  启动重试（上游先写后更新，但把异常吞进日志；这里失败要能被页面的「上次自动备份失败」看到）。
- 保留份数：`backup.retention` ∈ `1..30`，默认 **5**。每次成功写入后，在**同一位置**列出本应用写的
  `backup*.zip`（名字匹配 `^backup.*\.zip$`），按文件名里的日期（无日期则按修改时间）从新到旧排序，
  删掉超出 N 的。**只删匹配这个模式的文件**：用户放在同一文件夹里的其它 zip 一律不碰。
- 命名：自动与手动都是 `backup<yyyy-MM-dd>.zip`（同日多次导出会覆盖同名文件——这正是「保留份数」
  想要的粒度）；恢复前安全副本是 `backup-before-restore-<yyyyMMdd-HHmmss>.zip`，同上纳入份数管理。
- 加密开启时文件名后缀 `.zip.enc`，匹配模式相应放宽为 `^backup.*\.zip(\.enc)?$`。

## 决策 3 覆盖式恢复：一个事务里先清空再写入，且**先存一份安全副本**

- 恢复增加 `RestoreMode { merge, overwrite }`：`merge` 就是 ADR-0073 的语义；`overwrite` 在**同一个
  drift 事务**里先 `DELETE` 七张表（`book_sources` / `books` / `reading_progress` / `book_groups` /
  `bookmarks` / `read_records` / `rules`）再按备份写入。
- `preferences` 在两种模式下**都只做合并**：删掉本机独有的键会让「覆盖」变成「把不认识我的设置
  也一起删掉」，而设置项没有自然键可以对齐。这一点在页面上写明。
- **安全副本**：`overwrite` 前先把当前库完整导出并写到备份位置（走决策 1 的位置 + 决策 4 的加密）。
  写失败 → **中止恢复**（覆盖是不可逆的，宁可这次不做）。安全副本文件名带时间戳，不会覆盖既有备份。
- 页面：预览卡片上选择「合并 / 覆盖」；选覆盖时按钮文案与说明都变红并二次确认，确认文案里说明
  「会先写一份安全副本，位置在 X」。
- 上游那种「`bookshelf` 计划式删除、其它表按条插入」的混合语义**不照抄**：它与我们的自然键合并
  语义冲突，而「全清 + 全写」是唯一能解释清楚、也能被一次事务回滚的覆盖定义。

## 决策 4 整包加密用 `archive` 的 WinZip AES-256，口令存密钥库

- 加密是**整包**的：zip 里每个条目都是 AES-256（`ZipEncoder(password:)` / `ZipDecoder(password:)`），
  与上游「只加密敏感字段」不同——上游的做法会让「谁能打开备份」这件事取决于实现细节，而整包加密
  是用户能验证的（7-Zip / WinRAR 输口令即可）。加密后文件名 `backup<date>.zip.enc`，内容仍是标准
  zip，扩展名只是提示。
- **不新增加密库**：`archive` 已带 WinZip AES 实现（PBKDF2-HMAC-SHA1 派生，AES-256，SHA-1 强度用于
  口令派生属可接受范围；升级路径写在这里：将来换 Argon2id 需要新 ADR 与迁移）。
- 口令（`backup.password`）存在系统密钥库（决策 5），用户不设口令 = 不加密。恢复时：
  - 包是加密的且本机没有口令 → `backup.read.passwordRequired`，页面让用户输入（可勾「记住」写进密钥库）；
  - 口令错误 → `backup.read.badPassword`（`archive` 对错口令抛 `ArchiveException`）。
  - 「是不是加密包」由解码器**先看中央目录的通用标志位 bit 0**（加密位）判断，不靠异常类型猜。
- 自动备份也用同一个口令：否则「自动备份」会静默降级成明文。

## 决策 5 凭据进系统密钥库（`flutter_secure_storage`，BSD-3）

- 新端口 `SecretStore`（`read` / `write` / `delete`，字符串键值），`core/platform/` 提供实现：
  Android Keystore（`EncryptedSharedPreferences`）、Windows DPAPI、iOS Keychain；无实现的平台给
  「写入即丢弃 + warning」的兜底（与其它平台端口同一契约：不抛异常）。
- 存两类东西：**备份口令**（`backup.password`）与 **WebDAV 密码**（`backup.webdav.password`）。
  URL / 账号 / 保留份数 / 位置这些非密字段仍走 `shared_preferences`（C-NET-9）。
- 这比上游进一步：上游把 `webDavPassword` 用 `MD5(本地口令)` 加密后写进 `config.xml`（进备份），
  我们把凭据留在设备上、**不进备份**；换机后需重新填一次 WebDAV 密码，代价换掉「补充一份可爆破的
  密文」。
- **登记项（§3.7）**：`login_info` 与 Cookie 仍是明文/同级存储（ADR-0072），本次不动；将来把它们
  也搬进密钥库时一并处理。

## 决策 6 WebDAV：一个最小 REST-over-HTTP 客户端，只做备份文件的四条动作

- 端口在 `core/network/`（`WebDavClient`，实现 `DioWebDavClient`）：`list`（PROPFIND Depth: 1）、
  `upload`（PUT）、`download`（GET）、`delete`（DELETE）；Basic 认证；URL 必须 `https`，明文
  `http` 走 `allowPlainHttp`（C-SEC-2 的同一个开关）。
- 备份 feature 只发「上传这份字节 / 列出远端 / 取回这份 / 删掉这份」，**不做**「云端进度覆盖」
  「远端书籍同步」这类另一条产品线。
- 远端文件命名与本地一致（`backup<date>.zip[.enc]`），保留份数同样生效（列远端后删旧）。
- 失败只报错不阻塞：手动动作给 `FailureMessage`；自动备份的云端上传失败记 warning 并把
  「上次上传失败」显示在页面上，本地文件仍算成功（这一点与上游一致）。

## 后果

- 备份页从「两个按钮」变成「设置区 + 三个动作区 + 云端区」，但每个决定仍只有一处：
  位置、份数、口令、远端配置各一个字段。
- 覆盖式恢复是**破坏性**动作，因此安全副本是硬前置而不是提示；安全副本本身也受保留份数约束，
  所以它不会被无限堆叠。
- `flutter_secure_storage` 在 Windows 上把密文放在应用支持目录（DPAPI 保护），在 Android 上依赖
  Keystore；Linux 桌面版（本项目未发布）落到 libsecret，未验证。
- 未做且登记：备份口令的强度校验、密钥库不可用时的降级策略（当前是「不加密 + 页面警示」）、
  WebDAV 的连接测试按钮之外的诊断、云端进度同步、加密算法升级（Argon2id）。

## 登记（`docs/dev/roadmap.md` §3.7）

- 备份**范围**仍不含 Cookie / 校验历史 / 缓存（用户裁决保持现状）。
- 密钥库不可用（企业策略禁用 Keystore、CI 无 DPAPI）时备份只能不加密：页面警示 + warning 日志。
- 备份口令无强度校验（与 WebDAV 密码同级处理）。
- 自动备份只在启动时检查一次：长时间不重启的桌面会话不会中途备份。
