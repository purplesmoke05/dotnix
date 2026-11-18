project(
  'hyprland-pip-drag',
  'cpp',
  version: '2.0.0',
  default_options: ['buildtype=release', 'warning_level=2'],
)

# Hyprland 0.57 builds as C++26, so its headers need the same standard. / Hyprland 0.57 は C++26 でビルドされるので、ヘッダーにも同じ規格が要る。
cpp_compiler = meson.get_compiler('cpp')
if cpp_compiler.has_argument('-std=c++26')
  add_project_arguments('-std=c++26', language: 'cpp')
elif cpp_compiler.has_argument('-std=c++2c')
  add_project_arguments('-std=c++2c', language: 'cpp')
else
  error('A C++26 compiler is required to build against Hyprland 0.57')
endif

add_project_arguments('-DWLR_USE_UNSTABLE', '-fno-gnu-unique', language: 'cpp')

shared_module(
  meson.project_name(),
  'main.cpp',
  dependencies: [
    dependency('hyprland'),
    dependency('pixman-1'),
    dependency('libdrm'),
  ],
  install: true,
)
