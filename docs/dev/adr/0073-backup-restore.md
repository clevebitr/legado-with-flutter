# ADR-0073 M22-b：备份与恢复（zip + 每表一个 JSON）

- **状态：** Accepted（2026-10-25，用户四项裁决：范围 = 数据 + 设置；恢复 = 按自然键合并；
  格式 = 本仓格式带 manifest；归属 = 新建 `features/backup/`）
- **日期：** 2026-10-25
- **关联：** `docs/dev/ui-gap.md` §3 U12、§4 M22；`docs/dev/roadmap.md` §3.7、5.8；ADR-0071（书源与规则的
  导入导出）、ADR-0070（`rules` 表）、ADR-0072（`login_info` 明文存库）、ADR-0041（跨 feature 端口）、
  ADR-0056（迁移可重入，本次无 schema 变更）、C-SEC-5、C-PERF-4/5、C-DEP-7

## 背景

上游的「备份恢复」（`legado-upstream/.../help/storage/Backup.kt` / `Restore.kt` / `BackupConfig.kt`）是：

| 项 | 上游行为 |
|---|---|
| 产物 | `backup<yyyy-MM-dd>-<device>.zip`（设备名取 WebDAV 设置，空则只有日期；`onlyLatestBackup` 时固定 `backup.zip`） |
| 内容 | **每表一个 JSON**（`bookshelf.json` / `bookSource.json` / `bookGroup.json` / `bookmark.json` / `replaceRule.json` / `readRecord*.json` / …，无 manifest）+ `config.xml`（SharedPreferences 全量，含若干旧键迁移与 `webDavPassword` 的 AES 加密）+ 阅读/主题/封面配置 JSON |
| 恢复 | 解压到私有目录 → 逐表读：`bookshelf` 按「新增/更新/删除」计划、`bookGroup`/`homepage*`/`highlightRule` 等 `replaceAll`、其余 `insert` 且吞 `SQLiteConstraintException`、阅读时长汇总再对账 |
| 传输 | 本地路径 / SAF 目录 / WebDAV（`mode = local \| webdav \| both`），另有 1 天节流的自动备份 |

本仓此前**没有**备份能力：5.8 只做了单类导出（书源 payload、替换净化 `ReplaceRule`），
`docs/dev/roadmap.md` §3.7 也把「备份格式」登记为待裁决。U12 的验收是「导出 → 清库 → 恢复往返」。

本仓的表与上游不同构：主键是合成 `id`，身份是**自然键**（`books` 的 `sourceUrl+bookUrl`、
`book_sources` 的 `url+fingerprint`、`book_groups` 的 `name`、`bookmarks` 的四元组唯一键、
`reading_progress` 的 `(sourceUrl, bookUrl)` 主键），`rules` 是四类规则共用一张表、`payload` 存 JSON。
因此**照抄上游 JSON 字段没有意义**：上游的 `id` 落到本仓会撞号，本仓的 `rules.kind` 上游没有。

## 决策 1 备份范围 = 用户数据 + 设置，缓存与凭据不进备份

进 zip 的内容（一表一文件，文件名见决策 2）：

| 文件 | 来源表 | 说明 |
|---|---|---|
| `bookSources.json` | `book_sources` | 含 `payload`（未知键保真，ADR-0040 §决策 4）与用户态（`isEnabled` / `customOrder` / `isExploreEnabled` / `comment` / `loginInfo`） |
| `books.json` | `books` | 书架条目（含 `groupId`，恢复时按组名重映射） |
| `readingProgress.json` | `reading_progress` | 每本书停在哪 |
| `bookGroups.json` | `book_groups` | 分组 |
| `bookmarks.json` | `bookmarks` | 书签 |
| `readRecords.json` | `read_records` | 阅读会话记录 |
| `rules.json` | `rules` | 四类规则（`kind` 区分），`payload` 原样 |
| `preferences.json` | `shared_preferences` | 键值全量：`settings.*`（主题/字号/并发/明文 HTTP）、`reader.*`（排版/TTS）等 |

**不进备份**，并各留触发条件：

- `cache_entries`：可再生数据，且 12 小时 TTL 后即失效（ADR-0072 §决策 1 已在迁移里清过一次）。
- `cookies`：会话凭据，跨设备恢复等于把别人的登录态搬过去；SHARED_PREFERENCES 的 `allowPlainHttp`
  虽随备份走，但它对用户可见、且是用户自己的选择（见「后果」）。
- `source_checks`：本机诊断历史，`sourceId` 是合成 id，跨库无意义。
- `book_sources.login_info` 进备份（属用户态，重导入不覆盖），因此备份文件**含明文登录信息**：
  zip 落盘位置由用户选，页面在导出前明示这一点（`backupIncludeSecretsHint`）。

自动备份（上游的 1 天节流 + 保留份数）与 WebDAV 均**本批不做**，登记在 §3.7：前者要后台调度与
保留策略，后者另立（网络 + 密钥），与用户「WebDAV 另立」的裁决一致。

## 决策 2 格式 = zip 根目录一个 `manifest.json` + 每表一个 JSON

```
backup2026-10-25.zip
├── manifest.json
├── bookSources.json
├── books.json
├── readingProgress.json
├── bookGroups.json
├── bookmarks.json
├── readRecords.json
├── rules.json
└── preferences.json
```

`manifest.json`：

```json
{
  "formatVersion": 1,
  "createdAt": "2026-10-25T12:34:56.789Z",
  "appVersion": "0.1.0+1",
  "tables": ["bookSources.json", "books.json", "readingProgress.json",
             "bookGroups.json", "bookmarks.json", "readRecords.json", "rules.json"],
  "preferences": "preferences.json"
}
```

- **`formatVersion` 是唯一的兼容钩子**：本仓只接受 `<= 1`；读取更高版本给出
  `ParseFailureKind.unsupportedRule`（`rulePath: 'backup.restore.formatVersion'`），不猜。
- **每表文件是 JSON 数组**，元素是**列名（camelCase）→ 值**的对象，`id` 不导出（身份由自然键表达）；
  `DateTime` 一律 ISO-8601 UTC 字符串。空表也写文件（空数组），这样「这张表本来就没有数据」
  与「这份备份来自更早的版本、没有这张表」在恢复时是两件事。
- **`preferences.json` 是 JSON 对象**（键 → 字符串/数字/布尔/字符串数组），与上游 `config.xml` 同构同义，
  只是换成更易读、且不依赖 XML 解析的形式。写回时只写这份备份里出现的键（合并、不删除），
  报告里的「几项设置」就是真正写下去的键数。
- 文件名固定 `backup<yyyy-MM-dd>.zip`：本仓还没有「设备名」设置（上游那个字段属于 WebDAV），
  加一个只出现在文件名里的设置不值得。同名覆盖由系统保存对话框负责。
- 不承诺读上游 zip（用户裁决）：字段与主键不同构，硬映射会得到「看起来恢复了」的半成品；
  真需要时按「导入书源 / 导入净化规则」两个既有入口处理。

**大小上限（C-SEC-5 / C-PERF-5）**：整个 zip ≤ 64 MiB；条目数 ≤ 32；单条目解压后 ≤ 16 MiB；
所有条目解压后合计 ≤ 64 MiB。条目大小取 zip 中央目录里的声明值，**先校验再解压**
（`ArchiveFile.size` 是头字段，`content` 才触发解压），避免 zip 炸弹。

**容错口径（实现注记，2026-10-25 落地时补充）：** 条目按**文件名**匹配（`basename`），所以用户把
解压出来的 9 个文件重新压进一个文件夹也读得出来；同名条目出现两次判 `backup.read.duplicateEntry`
而不是任选一个。`manifest.json` 缺失 / 不是对象 / 字段类型不符 / `createdAt` 不可解析一律
`backup.read.badManifest`，版本更高则是 `unsupportedRule`；表文件缺失、不是数组、某行不是对象分别是
`backup.read.missingTable` / `backup.read.<表文件名>`。`archive` 4.x 的两种失败类型（结构坏 =
`ArchiveException`、流坏 = `FormatException`）都在编解码模块里统一成 `ParseFailure`，不允许异常
穿到用例层（C-ERR-1）。

## 决策 3 恢复 = 按自然键合并，从不删除

在**一个 drift 事务**里应用：先解压、解析、校验全部文件（任何一步失败 → 整次不落库），再写入。

| 表 | 自然键 | 已存在 | 不存在 |
|---|---|---|---|
| `bookGroups` | `name` | 不动 | 插入，`sortOrder` 排在现有最大之后 |
| `books` | `sourceUrl + bookUrl` | 只更新用户态（`status` / `isPinned` / `groupId` / `customCoverPath`），`tocUrl` 仅在本地为空时补 | 整行插入（`groupId` 按**组名**重映射） |
| `readingProgress` | `sourceUrl + bookUrl` | 仅当备份的 `updatedAt` 更晚才写（不把进度往回拨） | 插入 |
| `bookmarks` | `sourceUrl + bookUrl + chapterUrl + charOffset` | 不动 | 插入 |
| `readRecords` | `sourceUrl + bookUrl + startedAt` | 不动 | 插入 |
| `rules` | `kind + name` | 不动（本地编辑胜过备份） | 插入，`sortOrder` 排在同类之后 |
| `bookSources` | `url + fingerprint` | 刷新 `payload` 与用户态列 | 整行插入 |
| `preferences` | 键 | 写入（覆盖同名键） | 写入 |

- **「从不删除」是这次的立场**：恢复是「把备份里有的东西带回来」，不是「把这台设备变成备份那天」。
  覆盖语义（含清空）需要二次确认与「恢复前自动备份」两个前置，登记为后续触发项。
- **合成 id 一律不搬**：`books.json` 里写的是 `groupName` 而不是 `groupId`，恢复时按名查组、查不到
  就落「未分组」；书签/阅读记录本来就按 URL 引用，天然可搬。
- 单条目坏掉（缺身份字段、类型不符）→ 跳过该条目并计入 `skipped`，不失败整次；文件级坏掉
  （不是 JSON、不是数组、超限）→ 失败整次。
- 恢复完成后经端口通知装配根 `invalidate` 依赖设置的 provider（`Settings` 与阅读设置是
  `keepAlive`，不失效会让界面继续显示恢复前的主题/字号）：端口是备份 domain 声明的
  `RestoreCompletionHook`，实现绑定在 `app.dart`（ADR-0041 的同一机制）。

## 决策 4 归属 = 新建 `features/backup/`，二进制文件走两个新端口

- **新 feature**（`docs/dev/architecture.md` §1 第 2 步要求先确认边界，已裁决）：备份跨全部表，
  放进任何既有 feature 都会让那个 feature 去拥有别人的数据表。结构与其他 feature 一致：
  `domain/`（实体、仓储接口、用例、纯函数编解码）、`data/`（读 DAO / 写 DAO）、`presentation/`（页面、Notifier）。
- **压缩编解码放 `domain/`**：`archive` 是纯 Dart、无 Flutter / 平台 API，符合 `architecture.md` §3 例外二
  （无状态领域服务 / 纯函数模块）。`data/` 只负责「表 ↔ JSON 对象」，`domain` 的用例负责
  「对象 ↔ zip 字节」与恢复计划，`presentation` 只发事件。
- **平台端口**（`core/platform/`）：`BackupArchiveSaver`（建议文件名 + 字节 → 是否写出）、
  `BackupArchivePicker`（→ 名称 + 字节，含上限）。两者的实现都走 `file_selector`，与既有
  `JsonFileSaver` / `JsonFilePicker` 同一形态：取消不是失败，无对话框的平台给 fallback。
  `XTypeGroup` 只给扩展名与 MIME，不写死展示标签（C-UI-5）。
- **设置的读写复用 `core/storage/PreferenceStore`**：新增 `snapshot()`（全量键值）与
  `writeAll(Map)`（只写给出的键，不删）。这样备份不必知道 `settings.*` / `reader.*` 的键名，
  也不会因为新增一个设置项就漏备份；键名仍然只有各 feature 的仓储文件知道。
- 入口：「我的 → 备份与恢复」（页面在 `backup` feature，经 `AppNavigation` 打开，ADR-0042）。
  页面两个动作：导出（选位置 → 写 zip → 报条目数）、恢复（选 zip → 预览清单 → 确认 → 报每表新增/更新数）。

## 决策 5 新依赖 `archive`（MIT）

- `archive: ^4.5.2`（Brendan Duncan，**MIT**；传递依赖 `path`、`posix` 均宽松许可）。
  它此前只是 `build_runner` 的**dev 传递依赖**，现在提升为运行时直接依赖（C-DEP-6 要求
  `pubspec.yaml` 与 `docs/dev/tech-stack.md` 同步，`NOTICE.md` §5 记录核实结果）。
- 自研 zip 不可行：deflate 流式编解码 + 中央目录 + CRC 是几百行且要为平台差异兜底；
  `archive` 是纯 Dart、发行包自带、无原生库，符合 C-DEP-1。
- 备选 `flutter_archive`（原生实现）被否：它把编解码推给平台，与本项目「纯 Dart 优先、
  Windows/Android 行为一致」的取向相反，且多一层原生库许可审查。

## 后果

- **备份文件是明文**（含书源 `login_info`）。与库里的明文同级（ADR-0072 §决策 3），
  页面对此有明示；加密备份（上游 `BackupAES`）需要口令派生与密钥管理，登记触发 = 有用户
  把备份放到不可信位置的真实需求。
- `allowPlainHttp` 随 `preferences.json` 恢复：一旦用户在备份里打开过明文 HTTP，恢复到新设备后
  这个开关也是打开的。这是「恢复用户的选择」，不是悄悄放宽；设置页本来就显示该开关。
- 恢复只合并、不删除，所以「删掉的书源/书签」不会因为恢复旧备份而回来；反过来也不会因为
  误恢复旧备份而丢掉新数据。
- 无 schema 变更：本次不新增列/表，所以不动 dump 与迁移，但 `integration_test/on_disk_database_test.dart`
  的「每张新表都要真实写一次」不适用（没有新表）；恢复路径本身有真实数据库的用例覆盖。

## 登记（`docs/dev/roadmap.md` §3.7）

- 自动备份（1 天节流 / 保留份数）与 WebDAV 上传下载：本批不做。
- 覆盖式恢复（清空后写入）+ 恢复前自动备份：本批不做，触发 = 用户反馈「想真正回到备份那天」。
- 备份加密（口令或系统密钥库）：触发 = 备份需要放到不可信位置。
- 上游 zip 的读取：触发 = 出现「从上游迁移过来」的真实需求。
- `cookies` 与 `login_info` 的凭据分级存储：仍归 ADR-0072 的登记项（引入密钥库时一并改）。
