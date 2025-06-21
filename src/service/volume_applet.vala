public class VolumeApplet : Object {
  private Gtk.StatusIcon tray_icon = new Gtk.StatusIcon();
  private Gtk.IconTheme icon_theme = Gtk.IconTheme.get_default();
  private string icon_name_base;
  private string current_icon_name;
  private Gdk.Pixbuf current_icon;
  private string notification_summary;
  private Notify.Notification notification;
  private VolumeState state;

  public VolumeApplet(VolumeState state_, bool microphone) {
    if (microphone) {
      icon_name_base = "microphone-sensitivity";
      notification_summary = "Microphone Sensitivity";
    } else {
      icon_name_base = "audio-volume";
      notification_summary = "Audio Volume";
    }

    notification = new Notify.Notification("", null, null);

    state = state_;
    state.changed.connect(handle_change);

    update_icon(convert_volume(state.volume), state.muted);
    tray_icon.set_visible(true);
  }

  private void handle_change() {
    var volume = convert_volume(state.volume);
    var muted = state.muted;

    update_icon(volume, muted);
    send_notification(volume, muted);
  }

  private void send_notification(uint volume, bool muted) {
    string summary = null;
    if (muted) {
      summary = "%s — Muted".printf(notification_summary);
    } else {
      summary = "%s — %u%%".printf(notification_summary, volume);
    }

    notification.update(summary, null, null);
    notification.set_image_from_pixbuf(current_icon);
    notification.set_hint("value", volume);

    try {
      notification.show();
    } catch (Error error) {
      stderr.printf("Failed to show notification: %s\n", error.message);
    }
  }

  private void update_icon(uint volume, bool muted) {
    var icon_name = get_icon_name(volume, muted);
    if (icon_name == current_icon_name) {
      return;
    }

    Gdk.Pixbuf icon;
    try {
      icon = icon_theme.load_icon(icon_name, 0,
        Gtk.IconLookupFlags.USE_BUILTIN | Gtk.IconLookupFlags.FORCE_SYMBOLIC);
    } catch (Error error) {
      stderr.printf("Failed to get icon: %s\n", error.message);
      return;
    }

    current_icon_name = icon_name;
    current_icon = icon;

    tray_icon.set_from_pixbuf(current_icon);
  }

  private string get_icon_name(uint volume, bool muted) {
    if (volume == 0 || muted) {
      return icon_name_base + "-muted";
    } else if (volume < 35) {
      return icon_name_base + "-low";
    } else if (volume < 85) {
      return icon_name_base + "-medium";
    } else {
      return icon_name_base + "-high";
    }
  }

  private static uint convert_volume(double volume) {
    return (uint) Math.round(volume * 100);
  }
}
