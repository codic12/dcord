module main;

import std.stdio,
       std.algorithm,
       std.string,
       std.format,
       std.conv,
       std.array,
       std.json,
       std.traits,
       std.process,
       core.time;

import vibe.core.core;
import vibe.http.client;


import dcord.core,
       dcord.util.process,
       dcord.util.emitter;

import core.sys.posix.signal;
import etc.linux.memoryerror;

import dcord.util.string : camelCaseToUnderscores;

class BasicPlugin : Plugin {
  @Listener!(MessageCreate, EmitterOrder.AFTER)
  void onMessageCreate(MessageCreate event) {
    this.log.infof("MessageCreate: %s", event.message.content);
  }

  @Command("ping")
  void onPing(CommandEvent event) {
    event.msg.reply(format("Pong: %s", event.msg.author.serializeToJSON));
  }

  @Command("embed")
  void onEmbed(CommandEvent event) {
    auto embed = new MessageEmbed;
    embed.title = "TESTING";
    embed.color = 0x77dd77;
    embed.description = "lol hey man";
    event.msg.reply(embed);
  }

  //An example command that clears messages in the channel
  @Command("clear")
  void onClearMessages(CommandEvent event) {
    uint limit = 100;

    //This command can take an integer argument.
    if(event.args.length > 0){
      try {
        limit = event.args[0].to!int;
      }
      catch(Exception e){
        event.msg.reply("You must supply a number of messages to clear (100 max).\n```" ~
        this.bot.config.cmdPrefix ~ "clear <number>```");
        return;
      }
    }

    //Delete the command message itself
    event.msg.del();

    try {
      Message[] messages = this.client.getMessages(event.msg.channelID, limit, event.msg.id);

      if(messages.length > 0){
        this.client.deleteMessages(event.msg.channelID, messages);

        event.msg.replyf("I deleted %s messages for you.", messages.length).after(3.seconds).del();
      }
    }
    catch(Exception e){
      event.msg.replyf("%s", e.msg);
      return;
    }

  }

  @Command("whereami")
  void onWhereAmI(CommandEvent event) {
    auto chan = this.userVoiceChannel(event.msg.guild, event.msg.author);
    if (chan) {
      event.msg.reply(format("You're in channel `%s`", chan.name));
    } else {
      event.msg.reply("You are not in a voice channel!");
    }
  }


  Channel userVoiceChannel(Guild guild, User user) {
    this.log.infof("k: %s", guild.voiceStates.keys);
    this.log.infof("v: %s", guild.voiceStates.values);

    auto state = guild.voiceStates.pick(s => s.userID == user.id);
    if (!state) return null;
    return state.channel;
  }
}


void main(string[] args) {
  static if (is(typeof(registerMemoryErrorHandler)))
      registerMemoryErrorHandler();

  if (args.length <= 1) {
    writefln("Usage: %s <token>", args[0]);
    return;
  }

  BotConfig config;
  config.token = args[1];
  config.cmdPrefix = "";
  Bot bot = new Bot(config, LogLevel.trace);
  bot.loadPlugin(new BasicPlugin);
  bot.run();
  runEventLoop();
  return;
}
