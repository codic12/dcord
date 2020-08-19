module dcord.types.voice;

import std.stdio;

import dcord.types,
       dcord.client;


alias VoiceStateMap = ModelMap!(string, VoiceState);

/// Object representing a voice state
class VoiceState: IModel {
  mixin Model;

  Snowflake guildID;
  Snowflake channelID;
  Snowflake userID;
  string sessionID;
  bool deaf;
  bool mute;
  bool selfDeaf;
  bool selfMute;
  bool suppress;


  override string toString() { // stfu
    return format("<VoiceState %s (%s / %s /%s)>",
      this.sessionID,
      this.guildID,
      this.channelID,
      this.userID);
  }
  
  /// Get the guild of the voice state
  @property Guild guild() {
    return this.client.state.guilds[this.guildID];
  }

  /// Get the channel of the voice state
  @property Channel channel() {
    return this.client.state.channels[this.channelID];
  }
}
