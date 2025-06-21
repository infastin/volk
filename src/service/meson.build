vala_sources = files(
  'main.vala',
  'volume_applet.vala',
  'volume_service.vala',
  'volume_state.vala',
)

deps = [
  gio,
  glib,
  gobject,
  gtk3,
  libnotify,
  wireplumber,
  vala_posix,
  libm,
]

executable('volk',
  sources: vala_sources,
  dependencies: deps,
  install: true,
)
