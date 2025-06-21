project('volk', ['vala', 'c'],
  version: '0.1.0',
  license: 'MIT',
)

vapi_dir = meson.current_source_dir() / 'vapi'

add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

valac = meson.get_compiler('vala')
cc = meson.get_compiler('c')

subdir('src')
