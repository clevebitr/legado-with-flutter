#include "ax_log_filter.h"

#include <fcntl.h>
#include <io.h>

#include <cstdio>
#include <cstring>
#include <thread>

namespace {

// 只匹配这一条已知噪声。子串匹配（而不是整行匹配）是因为引擎行前面带
// `[ERROR:flutter/shell/platform/common/accessibility_bridge.cc(114)] ` 前缀，行号随版本变。
constexpr char kSuppressedFragment[] = "Failed to update ui::AXTree";

// 原始 stderr 的副本：stderr 自己被指向管道后，转发线程仍要有一个能写控制台的句柄。
int g_console_stderr = -1;

// 把 stderr 的每一行转发到原控制台，命中 kSuppressedFragment 的行丢掉。
//
// 这个循环**只在进程还活着时**有意义：stderr 指着管道，一旦没人持续读，管道缓冲区（64 KB）
// 写满后下一次日志就会阻塞写它的线程。所以它不设退出条件，随进程结束一起消失。
void PumpStderr(FILE* pipe) {
  char line[4096];
  while (std::fgets(line, sizeof(line), pipe) != nullptr) {
    if (std::strstr(line, kSuppressedFragment) != nullptr) {
      continue;
    }
    _write(g_console_stderr, line, static_cast<unsigned int>(std::strlen(line)));
  }
  std::fclose(pipe);
}

}  // namespace

void InstallAccessibilityLogFilter() {
  const int stderr_fd = _fileno(stderr);
  if (stderr_fd < 0) {
    return;  // 没有 errno 流（例如被宿主替换掉了），不做任何事。
  }

  int pipe_fds[2];
  if (_pipe(pipe_fds, 1 << 16, _O_BINARY) != 0) {
    return;
  }

  // 先包好读端再改 stderr：如果顺序反过来而 _fdopen 失败，stderr 会指向一个没有读者的管道，
  // 之后任何一次引擎日志都可能把线程卡死。
  FILE* reader = _fdopen(pipe_fds[0], "r");
  if (reader == nullptr) {
    _close(pipe_fds[0]);
    _close(pipe_fds[1]);
    return;
  }

  g_console_stderr = _dup(stderr_fd);
  if (g_console_stderr < 0 || _dup2(pipe_fds[1], stderr_fd) != 0) {
    if (g_console_stderr >= 0) {
      _close(g_console_stderr);
      g_console_stderr = -1;
    }
    std::fclose(reader);
    _close(pipe_fds[1]);
    return;
  }
  _close(pipe_fds[1]);

  // 无缓冲：每次日志调用直接落到管道，fgets 才能按整行读，而不是读到自己写进去的半行。
  setvbuf(stderr, nullptr, _IONBF, 0);

  std::thread(PumpStderr, reader).detach();
}
