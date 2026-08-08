project(
  'hyprland-pip-drag',
  'cpp',
  version: '1.0.0',
  default_options: ['buildtype=release', 'cpp_std=c++23', 'warning_level=2'],
)

add_project_arguments('-DWLR_USE_UNSTABLE', language: 'cpp')

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
