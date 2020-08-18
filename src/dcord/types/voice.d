module dcord.types.voice;

import std.stdio;

import dcord.types,
       dcord.client;


alias VoiceStateMap = ModelMap!(string, VoiceState);

class VoiceState : IModel {
  mixin Model;

  Snowflake  guildID;
  Snowflake  channelID;
  Snowflake  userID;
  string     sessionID;
  bool       deaf;
  bool       mute;
  bool       selfDeaf;
  bool       selfMute;
  bool       suppress;

  /*
  override void load(JSONDecoder obj) {
    obj.keySwitch!(
      "guild_id", "channel_id", "user_id", "session_id",
      "deaf", "mute", "self_deaf", "self_mute", "suppress"
    )(
      { this.guildID = readSnowflake(obj); },
      { this.channelID = readSnowflake(obj); },
      { this.userID = readSnowflake(obj); },
      { this.sessionID = obj.read!string; },
      { this.deaf = obj.read!bool; },
      { this.mute = obj.read!bool; },
      { this.selfDeaf = obj.read!bool; },
      { this.selfMute = obj.read!bool; },
      { this.suppress = obj.read!bool; },
    );
  }
  */

  override string toString() {
    return format("<VoiceState %s (%s / %s /%s)>",
      this.sessionID,
      this.guildID,
      this.channelID,
      this.userID);
  }

  @property Guild guild() {
    return this.client.state.guilds[this.guildID];
  }

  @property Channel channel() {
    return this.client.state.channels[this.channelID];
  }
}
