#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);

  // Finestra con proporzioni da telefono (430x900), ma mai piu' alta dello
  // spazio libero sullo schermo (es. portatili 1280x720): la barra in basso
  // deve restare visibile. Le misure sono "logiche" (scalate dal DPI).
  RECT work_area;
  ::SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0);
  HMONITOR monitor = ::MonitorFromWindow(nullptr, MONITOR_DEFAULTTOPRIMARY);
  const double scale = FlutterDesktopGetDpiForMonitor(monitor) / 96.0;
  const int free_height =
      static_cast<int>((work_area.bottom - work_area.top) / scale) - 60;
  const unsigned int height =
      static_cast<unsigned int>(free_height < 900 ? (free_height > 480 ? free_height : 480) : 900);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(430, height);
  if (!window.Create(L"Easy Lesson", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  // Rete di sicurezza: con scaling DPI particolari la finestra puo' comunque
  // risultare piu' alta dello schermo. Qui la misuriamo com'e' davvero
  // (pixel fisici) e, se esce dall'area di lavoro, la riadattiamo.
  RECT wr;
  if (::GetWindowRect(window.GetHandle(), &wr)) {
    RECT wa;
    ::SystemParametersInfo(SPI_GETWORKAREA, 0, &wa, 0);
    int w = wr.right - wr.left;
    int h = wr.bottom - wr.top;
    const int max_h = wa.bottom - wa.top;
    const int max_w = wa.right - wa.left;
    if (h > max_h) h = max_h;
    if (w > max_w) w = max_w;
    int x = wr.left;
    int y = wr.top;
    if (y + h > wa.bottom) y = wa.bottom - h;
    if (x + w > wa.right) x = wa.right - w;
    if (y < wa.top) y = wa.top;
    if (x < wa.left) x = wa.left;
    if (x != wr.left || y != wr.top || w != wr.right - wr.left ||
        h != wr.bottom - wr.top) {
      ::SetWindowPos(window.GetHandle(), nullptr, x, y, w, h, SWP_NOZORDER);
    }
  }

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
