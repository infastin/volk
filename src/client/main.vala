public errordomain SubcommandError {
  INVALID_INPUT,
  FAILED,
}

public delegate void SubcommandHandler(string[] args, VolumeProxy proxy) throws SubcommandError;

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
      "  [+/-]VOL - Step up/down volume by specified value (Example: +0.05)\n" +
      "  [+/-]VOL% - Step up/down volume by specified percent (Example: -5%)",
      handle_set,
    },
    {
      "mute", "0|false|1|true|t|toggle", "Mute/Unmute audio",
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
    var prg = Path.get_basename(args[0]);
    var context = new OptionContext("COMMAND [ARGS] - Manipulate volk service");

    context.add_main_entries(entries, null);
    context.set_summary(build_top_summary());
    context.set_description(@"Use '$prg help COMMAND' for more information about a command");
    context.set_strict_posix(true);

    try {
      context.parse(ref args);
    } catch (OptionError error) {
      stderr.printf("%s: failed to parse options: %s\n", prg, error.message);
      stderr.printf("Run '%s help'\n", prg);
      return Posix.EXIT_FAILURE;
    }

    if (args.length < 2) {
      var help = context.get_help(false, null);
      stderr.printf("%s", help);
      return Posix.EXIT_FAILURE;
    }

    var cmd_name = args[1];
    if (cmd_name == "help") {
      var help = context.get_help(false, null);
      try {
        show_help(prg, args[2:], help);
        return 0;
      } catch (Error error) {
        stderr.printf("%s: %s\n", prg, error.message);
        if (error is SubcommandError.INVALID_INPUT) {
          stderr.printf("Run '%s help'\n", prg);
        }
        return Posix.EXIT_FAILURE;
      }
    }

    Subcommand* cmd = null;
    for (int i = 0; i < subcommands.length; i++) {
      var subcommand = &subcommands[i];
      if (subcommand.name == cmd_name) {
        cmd = subcommand;
        break;
      }
    }
    if (cmd == null) {
      stderr.printf("%s: unknown command %s\n", prg, Shell.quote(cmd_name));
      stderr.printf("Run '%s help'\n", prg);
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
      stderr.printf("%s: failed to connect to DBus service: %s\n", prg, error.message);
      return Posix.EXIT_FAILURE;
    }

    try {
      cmd.handler(args[2:], proxy);
    } catch (Error error) {
      stderr.printf("%s: %s\n", prg, error.message);
      if (error is SubcommandError.INVALID_INPUT) {
        stderr.printf("Run '%s help %s'\n", prg, cmd_name);
      }
      return Posix.EXIT_FAILURE;
    }

    return 0;
  }

  private static void show_help(string prg, string[] args, string help) throws SubcommandError {
    if (args.length == 0) {
      stdout.printf("%s", help);
      return;
    }
    if (args.length > 1) {
      throw new SubcommandError.INVALID_INPUT("too many arguments");
    }

    var cmd_name = args[0];

    Subcommand* cmd = null;
    for (int i = 0; i < subcommands.length; i++) {
      var subcommand = &subcommands[i];
      if (subcommand.name == cmd_name) {
        cmd = subcommand;
        break;
      }
    }
    if (cmd == null) {
      throw new SubcommandError.INVALID_INPUT("command %s not found", Shell.quote(cmd_name));
    }

    stdout.printf("Usage:\n  %s %s %s - %s\n",
      prg, cmd_name, cmd.positional_args, cmd.summary);
    if (cmd.description != null) {
      stdout.printf("\n%s\n", cmd.description);
    }
  }

  private static void handle_set(string[] args, VolumeProxy proxy) throws SubcommandError {
    if (args.length == 0) {
      throw new SubcommandError.INVALID_INPUT("expected an argument");
    }
    if (args.length > 1) {
      throw new SubcommandError.INVALID_INPUT("too many arguments");
    }

    var arg = args[0];
    if (arg.length == 0) {
      throw new SubcommandError.INVALID_INPUT("invalid argument");
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
      arg = arg[:arg.length-1];
      uint perc = 0;
      if (!uint.try_parse(arg, out perc, null, 10)) {
        throw new SubcommandError.INVALID_INPUT("expected a number, got: %s\n", Shell.quote(arg));
      }
      val = ((double) perc) / 100.0;
    } else {
      if (!double.try_parse(arg, out val, null)) {
        throw new SubcommandError.INVALID_INPUT("expected a number, got: %s\n", Shell.quote(arg));
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
      throw new SubcommandError.FAILED("failed to change volume: %s\n", error.message);
    }
  }

  private static void handle_mute(string[] args, VolumeProxy proxy) throws SubcommandError {
    if (args.length == 0) {
      throw new SubcommandError.INVALID_INPUT("expected an argument");
    }
    if (args.length > 1) {
      throw new SubcommandError.INVALID_INPUT("too many arguments");
    }

    var arg = args[0];
    switch (arg) {
    case "0": case "false":
      proxy.muted = false;
      break;
    case "1": case "true":
      proxy.muted = true;
      break;
    case "t": case "toggle":
      proxy.muted = !proxy.muted;
      break;
    default:
      throw new SubcommandError.INVALID_INPUT("invalid argument: %s", arg);
    }
  }
}
