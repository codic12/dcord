module dcord.types.channel;

import std.stdio,
       std.format,
       std.variant,
       std.algorithm,
       core.vararg;

import dcord.types,
       dcord.client;

alias ChannelMap = ModelMap!(Snowflake, Channel);
alias PermissionOverwriteMap = ModelMap!(Snowflake, PermissionOverwrite);

/// Enumeration permission overwrites
enum PermissionOverwriteType {
  ROLE = "role",
  MEMBER = "member",
}

/// Enumeration of channel types
enum ChannelType: ushort {
  GUILD_TEXT = 0,
  DM = 1,
  GUILD_VOICE = 2,
  GROUP_DM = 3,
  GUILD_CATEGORY = 4,
}

/// A class representing a permission overwrite
class PermissionOverwrite: IModel {
  mixin Model;
  Snowflake id;

  // Overwrite type
  PermissionOverwriteType type;

  // Permissions
  Permission allow;
  Permission deny;

  // Parent channel
  Channel channel;
}

/// A channel object
class Channel: IModel, IPermissible {
  mixin Model;
  mixin Permissible;

  Snowflake id;
  Snowflake guildID;
  string name;
  string topic;
  Snowflake lastMessageID;
  short position;
  uint bitrate;
  ChannelType type;
  Snowflake parentID;

  @JSONListToMap("id")
  UserMap recipients;

  // Overwrites
  @JSONListToMap("id")
  @JSONSource("permission_overwrites")
  PermissionOverwriteMap overwrites;

  @property Guild guild() {
    return this.client.state.guilds.get(this.guildID);
  }

  override void initialize() {
    this.overwrites = new PermissionOverwriteMap;
  }

  override string toString() { // stfu
    return format("<Channel %s (%s)>", this.name, this.id);
  }

  Message sendMessage(inout(string) content, string nonce=null, bool tts=false) {
    return this.client.api.channelsMessagesCreate(this.id, content, nonce, tts, null);
  }

  Message sendMessagef(T...)(inout(string) content, T args) {
    return this.client.api.channelsMessagesCreate(this.id, format(content, args), null, false, null);
  }

  Message sendMessage(Sendable obj) {
    return this.client.api.channelsMessagesCreate(
      this.id,
      obj.getContents(),
      obj.getNonce(),
      obj.getTTS(),
      obj.getEmbed(),
    );
  }

  /// Whether this is a direct message
  @property bool DM() {
    return (
      this.type == ChannelType.DM ||
      this.type == ChannelType.GROUP_DM
    );
  }

  /// Whether this is a voice channel
  @property bool voice() {
    return (
      this.type == ChannelType.GUILD_VOICE ||
      this.type == ChannelType.GROUP_DM ||
      this.type == ChannelType.DM
    );
  }

  /// Whether this is a text channel
  @property bool text() {
    return (
      this.type == ChannelType.GUILD_TEXT ||
      this.type == ChannelType.DM ||
      this.type == ChannelType.GROUP_DM
    );
  }

  /// Whether this channel is a category
  @property bool category() {
    return this.type == ChannelType.GUILD_CATEGORY;
  }

  @property auto voiceStates() {
    return this.guild.voiceStates.filter(c => c.channelID == this.id);
  }

  override Permission getPermissions(Snowflake user) {
    GuildMember member = this.guild.getMember(user);
    Permission perm = this.guild.getPermissions(user);

    // Apply any role overwrites
    foreach (overwrite; this.overwrites.values) {
      if (overwrite.type != PermissionOverwriteType.ROLE) continue;
      if (!member.roles.canFind(overwrite.id)) continue;
      perm ^= overwrite.deny;
      perm |= overwrite.allow;
    }

    // Finally grab a user overwrite
    if (this.overwrites.has(member.id)) {
      perm ^= this.overwrites.get(member.id).deny;
      perm |= this.overwrites.get(member.id).allow;
    }

    return perm;
  }
}
