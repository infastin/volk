# volk — fast and simple volume tray icon

This application puts audio volume/microphone
sensitivity icon in your system tray.

Whenever the state of the default audio sink/source changes
the system tray icon is updated and a notification is sent.

Notification daemons (like [dunst](https://github.com/dunst-project/dunst))
should show volume bar in notifications.

This application uses PipeWire and WirePlumber, so it is
possible to change the audio sink/source state with `wpctl`.
It is also possible to do so with `volkctl`.

## Building

Build dependencies:
- Vala compiler
- C compiler
- meson
- ninja
- pkg-config

Dependencies:
- dbus (runtime)
- glib-2.0
- gtk-3.0
- libnotify
- wireplumber-0.5
- libc

Building and installing:

```
meson setup build
ninja -C build
ninja -C build install
```
