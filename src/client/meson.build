vala_sources = files(
  'main.vala',
  'volume_proxy.vala',
)

deps = [
  gio,
  glib,
  gobject,
  vala_posix,
]

executable('volkctl',
  sources: vala_sources,
  dependencies: deps,
  install: true,
)
