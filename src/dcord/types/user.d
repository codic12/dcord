module dcord.types.user;

import std.stdio,
       std.format,
       std.algorithm.searching;

import std.conv : to;

import dcord.types,
       dcord.client;

alias UserMap = ModelMap!(Snowflake, User);

/// Enumeration of available game types
enum GameType: short {
  DEFAULT = 0,
  STREAMING = 1,
  LISTENING = 2,
  WATCHING = 3,
}

/// Enumeration of available statues (online/idle/dnd/invisible/offline)
enum UserStatus: string {
  ONLINE = "online",
  IDLE = "idle",
  DND = "dnd",
  INVISIBLE = "invisible",
  OFFLINE = "offline",
}

/// Enumeration of default avatar colors, assigned as integers to names
enum DefaultAvatarColor {
  BLURPLE = 0,
  GREY = 1,
  GREEN = 2,
  ORANGE = 3,
  RED = 4,
}

class Game {
  string name;
  string url;
  GameType type;

  this(string name="", string url="", GameType type=GameType.DEFAULT) {
    this.name = name;
    this.url = url;
    this.type = type;
  }

  // TODO: remove
  VibeJSON dump() { 
    VibeJSON obj = VibeJSON.emptyObject;

    obj["name"] = VibeJSON(this.name);

    if (this.url != "") {
      obj["url"] = VibeJSON(this.url);
      obj["type"] = VibeJSON(cast(ushort)this.type);
    }

    return obj;
  }
}

class Presence: IModel {
  mixin Model;

  User user; /// the user that the presence is coming from
  Game game; /// a Game object for the presence
  UserStatus status; /// user status
}

class User: IModel {
  mixin Model;
  /// The user's ID
  Snowflake id;
  /// The user's username
  string username;
  /// The user's unique four digit discriminator
  string discriminator;
  /// A URL pointing to the user's avatar
  string avatar;
  /// A boolean representing whether the user is verified
  bool verified;
  /// The user's email, if the account is linked with one
  string email;

  override string toString() { // stfu
    return format("<User %s#%s (%s)>", this.username, this.discriminator, this.id);
  }

  string getAvatarURL(string fmt = null, size_t size = 1024) {
    // TODO: when Discord moves it's CDN to cdn.discord.com, move accordingly to avoid overhead of redirects
    if (!this.avatar) { // if no avatar is detected
      return format("https://cdn.discordapp.com/embed/avatars/%s.png", cast(int)this.defaultAvatarColor); // return the default avatar
    }

    if (fmt is null) {
      fmt = this.avatar.startsWith("a_") ? "gif" : "webp";
    }

    return format("https://cdn.discordapp.com/avatars/%s/%s.%s?size=%s", this.id, this.avatar, fmt, size);
  }

  @property DefaultAvatarColor defaultAvatarColor() {
    auto discrimNumber = this.discriminator.to!int;

    return cast(DefaultAvatarColor)(discrimNumber % DefaultAvatarColor.sizeof);
  }
}
