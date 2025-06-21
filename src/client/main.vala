public delegate int SubcommandHandler(string prg, string[] args, VolumeProxy proxy);

public struct Subcommand {
  public string name;
  public string positional_args;
  public string summary;
  public string? description;
  public unowned SubcommandHandler handler;
}

public class VolkClient : Object {
  private static bool microphone = false;

  private const OptionEntry[] entries = {
    { "microphone", 'm', 0, OptionArg.NONE, ref microphone, "Manage microphone", null, },
    { null },
  };

  private const Subcommand[] subcommands = {
    {
      "set", "[+/-]VOL[%]", "Set audio volume",

      "Set the volume based on the specified argument.\n" +
      "  VOL - Set volume as the specified floating point value (Example: 0.5)\n" +
      "  VOL% - Set volume as the specified percentage (Example: 50%)\n" +
      "  [+/-]VOL - Step up/down volume by specified value (Example: +0.05)" +
      "  [+/-]VOL% - Step up/down volume by specified percent (Example: -5%)\n",

      handle_set,
    },
    {
      "mute", "false|0|true|1|toggle", "Mute/Unmute audio",
      null,
      handle_mute,
    },
  };

  private static string build_top_summary() {
    var subcommand_name_len = subcommands[0].name.length;
    var subcommand_pos_args_len = subcommands[0].positional_args.length;
    for (int i = 1; i < subcommands.length; i++) {
      var subcommand = &subcommands[i];
      if (subcommand.name.length > subcommand_name_len) {
        subcommand_name_len = subcommand.name.length;
      }
      if (subcommand.positional_args.length > subcommand_pos_args_len) {
        subcommand_pos_args_len = subcommand.positional_args.length;
      }
    }

    var summary = new StringBuilder("Commands:");
    for (int i = 0; i < subcommands.length; i++) {
      var subcommand = &subcommands[i];
      summary.append_printf("\n  %-*s  %-*s    %s",
        subcommand_name_len, subcommand.name,
        subcommand_pos_args_len, subcommand.positional_args,
        subcommand.summary);
    }

    return summary.free_and_steal();
  }

  public static int main(string[] args) {
    var context = new OptionContext("COMMAND [ARGS] - Manipulate volk service");

    context.add_main_entries(entries, null);
    context.set_summary(build_top_summary());
    context.set_strict_posix(true);

    try {
      context.parse(ref args);
    } catch (OptionError error) {
      stderr.printf("Failed to parse options: %s\n", error.message);
      return Posix.EXIT_FAILURE;
    }

    if (args.length < 2) {
      var help = context.get_help(false, null);
      stdout.printf("%s", help);
      return Posix.EXIT_FAILURE;
    }

    Subcommand* cmd = null;
    for (int i = 0; i < subcommands.length; i++) {
      var subcommand = &subcommands[i];
      if (subcommand.name == args[1]) {
        cmd = subcommand;
        break;
      }
    }
    if (cmd == null) {
      var help = context.get_help(false, null);
      stdout.printf("%s", help);
      return Posix.EXIT_FAILURE;
    }

    string conn_name;
    if (microphone) {
      conn_name = "com.github.infastin.volk.microphone";
    } else {
      conn_name = "com.github.infastin.volk.audio";
    }

    VolumeProxy proxy;
    try {
      proxy = Bus.get_proxy_sync(
        BusType.SESSION,
        conn_name,
        "/com/github/infastin/volk"
      );
    } catch (IOError error) {
      stderr.printf("Failed to connect to DBus service: %s\n", error.message);
      return Posix.EXIT_FAILURE;
    }

    var prg = Path.get_basename(args[0]);
    return cmd.handler(prg, args[2:], proxy);
  }

  private static int handle_set(string prg, string[] args, VolumeProxy proxy) {
    if (args.length == 0) {
      stderr.printf("%s: expected an argument\n", prg);
      return Posix.EXIT_FAILURE;
    }

    if (args.length > 1) {
      stderr.printf("%s: too many arguments\n", prg);
      return Posix.EXIT_FAILURE;
    }

    var arg = args[0];
    if (arg.length == 0) {
      stderr.printf("%s: invalid argument\n", prg);
      return Posix.EXIT_FAILURE;
    }

    bool inc = false;
    bool dec = false;
    if (arg[0] == '+' || arg[0] == '-') {
      if (arg[0] == '+') {
        inc = true;
      } else {
        dec = true;
      }
      arg = arg[1:];
    }

    double val = 0;
    if (arg[arg.length-1] == '%') {
      var num = arg[:arg.length-1];
      uint perc = 0;
      if (!uint.try_parse(num, out perc, null, 10)) {
        stderr.printf("%s: expected a number, got: %s\n", prg, Shell.quote(num));
        return Posix.EXIT_FAILURE;
      }
      val = ((double) perc) / 100.0;
    } else {
      if (!double.try_parse(arg, out val, null)) {
        stderr.printf("%s: expected a number, got: %s\n", prg, Shell.quote(arg));
        return Posix.EXIT_FAILURE;
      }
    }
    val = val.clamp(0, 1.5);

    try {
      if (inc) {
        proxy.add_volume(val);
      } else if (dec) {
        proxy.add_volume(-val);
      } else {
        proxy.volume = val;
      }
    } catch (Error error) {
      stderr.printf("%s: failed to change volume: %s\n", prg, error.message);
      return Posix.EXIT_FAILURE;
    }

    return 0;
  }

  private static int handle_mute(string prg, string[] args, VolumeProxy proxy) {
    if (args.length == 0) {
      stderr.printf("%s: expected an argument\n", prg);
      return Posix.EXIT_FAILURE;
    }

    if (args.length > 1) {
      stderr.printf("%s: too many arguments\n", prg);
      return Posix.EXIT_FAILURE;
    }

    switch (args[0]) {
    case "0": case "false":
      proxy.muted = false;
      break;
    case "1": case "true":
      proxy.muted = true;
      break;
    case "toggle":
      proxy.muted = !proxy.muted;
      break;
    default:
      stderr.printf("%s: invalid argument: %s\n", prg, args[0]);
      return Posix.EXIT_FAILURE;
    }

    return 0;
  }
}
