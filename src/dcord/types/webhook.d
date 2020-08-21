/// Classes related to webhooks
module dcord.types.webhook;

import dcord.types, std.typecons, vibe.data.json, std.stdio, std.conv;

/// A Webhook object
class Webhook {
  /// The client instance that the webhook is linked to
  Client client;
  /// The webhook's URL
  string url;
  /// The webhook's name
  string name;
  /// The webhook's token
  string token;
  /// The webhook's type
  int type;
  /// The webhook's avatar
  Nullable!(string) avatar;
  /// URL to the webhook's avatar
  Nullable!(string) avatarUrl;
  /// The channel ID snowflake
  Snowflake channelID;
  /// The guild ID snowflake
  Snowflake guildID;
  /// The Application ID snowflake
  Snowflake applicationID;
  /// The snowflake of the actual webhook's ID
  Snowflake id;
  this(Client client, Snowflake id) {
    this.id = id;
    this.client = client;
    VibeJSON payload = client.api.getWebhook(this.id);
    writeln(payload);
    this.name = payload["name"].to!string;
    this.type = payload["type"].to!int;
    if(payload["avatar"].type != Json.Type.null_) this.avatar = payload["avatar"].to!string;
    this.channelID = payload["channelID"].to!int;
    this.guildID = payload["guildID"].to!int;
    this.applicationID = payload["applicationID"].to!int;
    this.token = payload["token"].to!string;
    this.url = "https://discord.com/api/webhooks/" ~ this.id.to!string ~ "/" ~ this.token;
    if(!this.avatar.isNull)
      this.avatarUrl = "https://cdn.discordapp.com/avatars/" ~ this.id.to!string ~ "/" ~ this.avatar;
  }
  void sendMessage(inout(string) content, inout(string) nonce=null, inout(bool) tts=false, inout(MessageEmbed[]) embeds=null) {
    this.client.api.sendWebhookMessage(this.id, this.token, content, nonce, tts, embeds);
  }
  void sendMessage(inout(string) content, inout(string) nonce=null, inout(bool) tts=false, inout(MessageEmbed) embed=null) {
    this.client.api.sendWebhookMessage(this.id, this.token, content, nonce, tts, embed);
  }
  void deleteWebhook() {
    this.client.api.deleteWebhook(this.id);
  }
}

