public class Volk : Object {
  private Wp.Core wp_core;
  private Wp.ObjectManager wp_om;
  private Wp.Plugin wp_default_nodes;
  private Wp.Plugin wp_mixer;

  private uint bus_owned_id;
  private VolumeState state = new VolumeState();
  private VolumeService service;
  private VolumeApplet applet;

  private static bool microphone = false;
  private static int exit_code = Posix.EXIT_SUCCESS;
  private static int pending_plugins = 2;

  private const OptionEntry[] entries = {
    { "microphone", 'm', 0, OptionArg.NONE, ref microphone, "Start for microphone", null, },
    { null },
  };

  public void init(Wp.Core wp_core_, Wp.ObjectManager wp_om_) {
    wp_core = wp_core_;
    wp_om = wp_om_;
    wp_default_nodes = Wp.Plugin.find(wp_core, "default-nodes-api");

    wp_mixer = Wp.Plugin.find(wp_core, "mixer-api");
    wp_mixer.set("scale", 1 /* cubic */, null);

    service = new VolumeService(
      state,
      wp_core, wp_om,
      wp_default_nodes, wp_mixer,
      microphone ? "Audio/Source" : "Audio/Sink"
    );

    string conn_name;
    if (microphone) {
      conn_name = "com.github.infastin.volk.microphone";
    } else {
      conn_name = "com.github.infastin.volk.audio";
    }

    bus_owned_id = Bus.own_name(
      BusType.SESSION, conn_name,
      BusNameOwnerFlags.NONE,
      setup_application,
      () => {},
      () => {
        stderr.printf("Could not acquire connection name\n");
        exit_code = Posix.EXIT_FAILURE;
        Gtk.main_quit();
      }
    );
  }

  ~Volk() {
    Bus.unown_name(bus_owned_id);
  }

  private void setup_application(DBusConnection conn) {
    try {
      conn.register_object("/com/github/infastin/volk", service);
    } catch (IOError error) {
      stderr.printf("Could not register service: %s\n", error.message);
      exit_code = Posix.EXIT_FAILURE;
      Gtk.main_quit();
      return;
    }
    applet = new VolumeApplet(state, microphone);
  }

  public static int main(string[] args) {
    Wp.init(Wp.InitFlags.ALL);
    Notify.init("volk");
    Gtk.init(ref args);

    var context = new OptionContext();

    context.add_main_entries(entries, null);
    context.add_group(Gtk.get_option_group(true));

    try {
      context.parse(ref args);
    } catch (OptionError error) {
      stderr.printf("Failed to parse options: %s\n", error.message);
      return Posix.EXIT_FAILURE;
    }

    var wp_core = new Wp.Core(null, null, null);

    var wp_om = new Wp.ObjectManager();
    wp_om.add_interest(typeof(Wp.Node), null);
    wp_om.add_interest(typeof(Wp.Client), null);
    wp_om.request_object_features(typeof(Wp.GlobalProxy), Wp.ProxyFeatures.PIPEWIRE_OBJECT_FEATURES_MINIMAL);

    wp_core.load_component.begin(
      "libwireplumber-module-default-nodes-api", "module",
      null, null, null,
      (obj, res) => wp_plugin_loaded((Wp.Core) obj, res, wp_om)
    );

    wp_core.load_component.begin(
      "libwireplumber-module-mixer-api", "module",
      null, null, null,
      (obj, res) => wp_plugin_loaded((Wp.Core) obj, res, wp_om)
    );

    if (!wp_core.connect()) {
      stderr.printf("Failed to connect to PipeWire\n");
      return Posix.EXIT_FAILURE;
    }

    var volk = new Volk();

    wp_core.disconnected.connect(() => {
      stderr.printf("Disconnected from wireplumber\n");
      exit_code = Posix.EXIT_FAILURE;
      Gtk.main_quit();
    });

    wp_om.installed.connect(() => volk.init(wp_core, wp_om));

    Process.signal(ProcessSignal.INT, signal_quit);
    Process.signal(ProcessSignal.QUIT, signal_quit);
    Process.signal(ProcessSignal.TERM, signal_quit);

    Gtk.main();
    Notify.uninit();

    return exit_code;
  }

  private static void wp_plugin_loaded(Wp.Core core, AsyncResult res, Wp.ObjectManager om) {
    try {
      core.load_component.end(res);
    } catch (Error error) {
      stderr.printf("Failed to load plugin: %s\n", error.message);
      exit_code = Posix.EXIT_FAILURE;
      Gtk.main_quit();
      return;
    }

    if (--pending_plugins == 0) {
      core.install_object_manager(om);
    }
  }

  private static void signal_quit(int signum) {
    stderr.printf("Got signal %d, exiting...\n", signum);
    exit_code = Posix.EXIT_FAILURE;
    Gtk.main_quit();
  }
}
