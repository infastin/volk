public errordomain MixerError {
  VOLUME_NOT_SUPPORTED,
  MUTE_NOT_SUPPORTED
}

[DBus(name = "com.github.infastin.volk")]
public class VolumeService : Object {
  private VolumeState state;
  private Wp.Core wp_core;
  private Wp.ObjectManager wp_om;
  private Wp.Plugin wp_default_nodes;
  private Wp.Plugin wp_mixer;
  private string media_class;
  private uint node_id;

  public VolumeService(VolumeState state_,
                       Wp.Core wp_core_, Wp.ObjectManager wp_om_,
                       Wp.Plugin wp_default_nodes_, Wp.Plugin wp_mixer_,
                       string media_class_) {
    state = state_;
    wp_core = wp_core_;
    wp_om = wp_om_;
    wp_default_nodes = wp_default_nodes_;
    wp_mixer = wp_mixer_;
    media_class = media_class_;

    Signal.connect_swapped(wp_default_nodes, "changed", (Callback) handle_default_nodes_change, this);
    Signal.connect_swapped(wp_mixer, "changed", (Callback) handle_mixer_change, this);

    update_default_node();
    update_state();
  }

  public double volume {
    get { return state.volume; }
    set {
      try {
        set_node_volume(value);
      } catch (MixerError error) {
        stderr.printf("%s\n", error.message);
      }
    }
  }

  public void add_volume(double delta) throws Error {
    set_node_volume(state.volume + delta);
  }

  public bool muted {
    get { return state.muted; }
    set {
      try {
        set_node_mute(value);
      } catch (MixerError error) {
        stderr.printf("%s\n", error.message);
      }
    }
  }

  private void handle_default_nodes_change() {
    update_default_node();
    update_state();
  }

  private void handle_mixer_change(uint id) {
    if (id != node_id) {
      return;
    }
    update_state();
  }

  private void update_default_node() {
    Signal.emit_by_name(wp_default_nodes, "get-default-node", media_class, ref node_id);
  }

  private void update_state() {
    Variant variant = null;
    Signal.emit_by_name(wp_mixer, "get-volume", node_id, ref variant);
    if (variant == null) {
      stderr.printf("Node %u doesn't support volume\n", node_id);
      return;
    }

    double volume = 1.0;
    bool muted = false;

    variant.lookup("volume", "d", ref volume);
    variant.lookup("mute", "b", ref muted);

    state.update(volume, muted);
  }

  private bool set_node_volume(double vol) throws MixerError {
    vol = vol.clamp(0.0, 1.5);

    var b = new VariantBuilder(VariantType.VARDICT);
    b.add("{sv}", "volume", new Variant.double(vol));
    var variant = b.end();

    bool ok = false;
    Signal.emit_by_name(wp_mixer, "set-volume", node_id, variant, ref ok);
    if (!ok) {
      throw new MixerError.VOLUME_NOT_SUPPORTED("Node %u doesn't support volume", node_id);
    }

    return ok;
  }

  private bool set_node_mute(bool mute) throws MixerError {
    var b = new VariantBuilder(VariantType.VARDICT);
    b.add("{sv}", "mute", new Variant.boolean(mute));
    var variant = b.end();

    bool ok = false;
    Signal.emit_by_name(wp_mixer, "set-volume", node_id, variant, ref ok);
    if (!ok) {
      throw new MixerError.MUTE_NOT_SUPPORTED("Node %u doesn't support mute", node_id);
    }

    return ok;
  }
}
