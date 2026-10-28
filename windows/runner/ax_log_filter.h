#ifndef RUNNER_AX_LOG_FILTER_H_
#define RUNNER_AX_LOG_FILTER_H_

// 只在 Windows 桌面生效：把 Flutter 引擎自己写到 stderr 的**一条已知无效噪声**过滤掉。
//
// 背景：`flutter run` / 带控制台的 exe 会不停打印
//   [ERROR:flutter/shell/platform/common/accessibility_bridge.cc(114)]
//   Failed to update ui::AXTree, error: 45 will not be in the tree and is not the new root
// 这是 Flutter 引擎无障碍桥的已知缺陷（upstream: flutter/flutter#182444，状态 open，
// 标签 platform-windows / a: accessibility），成因是辅助技术客户端连接后语义树的增量更新
// 把某个节点判成「不在树里也不是新根」。它**不影响功能**，但会淹没真正的日志。
//
// 过滤做在 runner 这一层，因为它写在引擎的 C++ 侧、Dart 拿不到；而引擎日志本身与我们的
// 业务日志是两条通道（业务日志走 `AppLogger`，见 docs/dev/adr/0082 / 0084）。
//
// 边界（刻意的）：
//   * 只拦**包含** `Failed to update ui::AXTree` 的行，其他引擎/插件/Dart 输出一条不动；
//   * 只在有控制台时安装（`AttachConsole` 成功且 stderr 可用），没有控制台就什么都不做；
//   * 不改变语义树、不影响无障碍功能本身，也不改引擎行为——只是把这一行从控制台里拿掉。
void InstallAccessibilityLogFilter();

#endif  // RUNNER_AX_LOG_FILTER_H_
