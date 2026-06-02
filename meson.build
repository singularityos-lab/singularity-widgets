project('singularity-widgets', ['vala', 'c'],
  version: '0.1.0',
  meson_version: '>= 0.59.0'
)

gtk_dep = dependency('gtk4')
gee_dep = dependency('gee-0.8')

libsingularity_dep = dependency('singularity-1.0',
  fallback: ['libsingularity', 'libsingularity_dep']
)

if not meson.is_subproject() and libsingularity_dep.type_name() == 'internal'
  libsingularity_vapi_dir = join_paths(meson.project_build_root(), 'subprojects', 'libsingularity')
  add_project_arguments(['--vapidir=' + libsingularity_vapi_dir], language: 'vala')
endif

widget_deps = [gtk_dep, gee_dep, libsingularity_dep]
widget_libdir  = get_option('libdir') / 'singularity' / 'widgets'
widget_datadir = get_option('datadir') / 'singularity' / 'widgets'

shared_module('singularity-builtin-widgets',
  ['builtin/clock_widget.vala'],
  dependencies: widget_deps,
  install: true,
  install_dir: widget_libdir
)
install_data('builtin/dev.sinty.builtin.clock.widget', install_dir: widget_datadir)

shared_module('singularity-calculator-widget',
  ['calculator/calculator_widget.vala'],
  dependencies: widget_deps,
  install: true,
  install_dir: widget_libdir
)
install_data('calculator/dev.sinty.calculator.basic.widget', install_dir: widget_datadir)
