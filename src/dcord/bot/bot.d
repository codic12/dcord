/**
  A simple but extendable Discord bot implementation.
*/

module dcord.bot.bot;

import std.algorithm,
       std.array,
       std.experimental.logger,
       std.regex,
       std.functional,
       std.string : strip, toStringz, fromStringz;

import dcord.bot,
       dcord.types,
       dcord.client,
       dcord.gateway,
       dcord.util.emitter,
       dcord.util.errors;

/**
  Feature flags that can be used to toggle behavior of the Bot interface.
*/
enum BotFeatures {
  /** This bot will parse/dispatch commands */
  COMMANDS = 1 << 1,
}

/**
  Configuration that can be used to control the behavior of the Bot.
*/
struct BotConfig {
  /** API Authentication Token */
  string token;

  /** Shard number of this instance */
  ushort shard = 0;

  /** The total number of shards */
  ushort numShards = 1;

  /** Bitwise flags from `BotFeatures` */
  uint features = BotFeatures.COMMANDS;

  /** Command prefix (can be empty for none) */
  string cmdPrefix = "?";

  /** Whether the bot requires mentioning to respond */
  bool cmdRequireMention = false;

  /** Whether the bot should use permission levels */
  bool levelsEnabled = false;

  @property ShardInfo* shardInfo() {
    return new ShardInfo(this.shard, this.numShards);
  }
}

/**
  The Bot class is an extensible, fully-featured base for building Bots with the
  dcord library. It's meant to serve as a base class that can be extended in
  seperate projects.
*/
class Bot {
  Client client;
  BotConfig config;
  Logger log;

  Plugin[string]  plugins;

  this(this T)(BotConfig bc, LogLevel lvl=LogLevel.all) {
    this.config = bc;
    this.client = new Client(this.config.token, lvl, this.config.shardInfo);
    this.log = this.client.log;

    if(this.feature(BotFeatures.COMMANDS)) this.client.events.listen!MessageCreate(&this.onMessageCreate, EmitterOrder.BEFORE);
    
  }

  /**
    Loads a plugin into the bot, optionally restoring previous plugin state.
  */
  void loadPlugin(Plugin p, PluginState state = null) {
    p.load(this, state);
    this.plugins[p.name] = p;

    // Bind listeners
    foreach (ref listener; p.listeners) {
      this.log.infof("Registering listener for event %s", listener.clsName);
      listener.listener = this.client.events.listenRaw(listener.clsName, toDelegate(listener.func), listener.order);
    }
  }


  /**
    Unloads a plugin from the bot, unbinding all listeners and commands.
  */
  void unloadPlugin(Plugin p) {
    p.unload(this);
    this.plugins.remove(p.name);

    foreach (ref listener; p.listeners) {
      listener.listener.unbind();
    }
  }

  /**
    Unloads a plugin from the bot by name.
  */
  void unloadPlugin(string name) {
    this.unloadPlugin(this.plugins[name]);
  }

  /**
    Returns true if the current bot instance/configuration supports all of the
    passed BotFeature flags.
  */
  bool feature(BotFeatures[] features...) {
    return (this.config.features & reduce!((a, b) => a & b)(features)) > 0;
  }

  private void tryHandleCommand(CommandEvent event) {
    // If we require a mention, make sure we got it
    if (this.config.cmdRequireMention) {
      if (!event.msg.mentions.length) {
        return;
      } else if (!event.msg.mentions.has(this.client.state.me.id)) {
        return;
      }
    }

    // Strip all mentions and spaces from the message
    string contents = strip(event.msg.withoutMentions);

    // If the message doesn't start with the command prefix, break
    if (this.config.cmdPrefix.length) {
      if (!contents.startsWith(this.config.cmdPrefix)) {
        return;
      }

      // Replace the command prefix from the string
      contents = contents[this.config.cmdPrefix.length..contents.length];
    }

    // Iterate over all plugins and check for command matches
    Captures!string capture;
    foreach (ref plugin; this.plugins.values) {
      foreach (ref command; plugin.commands) {
        if (!command.enabled) continue;

        auto c = command.match(contents);
        if (c.length) {
          event.cmd = command;
          capture = c;
          break;
        }
      }
    }

    // If we didn't match any CommandObject, carry on our merry way
    if (!capture) {
      return;
    }

    // Extract some stuff for the CommandEvent
    if (capture.back.length) {
      event.contents = strip(capture.back);
    } else {
      event.contents = strip(capture.post);
    }

    event.args = event.contents.split(" ");

    if (event.args.length && event.args[0] == "") {
      event.args = event.args[1..$];
    }

    // Check permissions (if enabled)
    if (this.config.levelsEnabled) {
      if (this.getLevel(event) < event.cmd.level) {
        return;
      }
    }

    // Set the command event so other people can introspect it
    event.event.commandEvent = event;
    event.cmd.call(event);
  }

  private void onMessageCreate(MessageCreate event) {
    if (this.feature(BotFeatures.COMMANDS)) {
      this.tryHandleCommand(new CommandEvent(event));
    }
  }

  /**
    Starts the bot.
  */
  void run() {
    client.gw.start();
  }

  /// Base implementation for getting a level from a user. Override this.
  int getLevel(User user) {
    return 0;
  }

  /// Base implementation for getting a level from a role. Override this.
  int getLevel(Role role) {
    return 0;
  }

  /// Override implementation for getting a level from a user (for command handling)
  int getLevel(CommandEvent event) {
    // If we where sent in a guild, check role permissions
    int roleLevel = 0;
    if (event.msg.guild) {
      auto guild = event.msg.guild;
      auto member = guild.getMember(event.msg.author);

      if (member && member.roles) {
        roleLevel = member.roles.map!(rid => this.getLevel(guild.roles.get(rid))).reduce!max;
      }
    }

    return max(roleLevel, this.getLevel(event.msg.author));
  }

}
