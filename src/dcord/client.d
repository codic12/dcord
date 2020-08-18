/**
  The top API abstraction encompassing REST, WS/Gateway, and state tracking.
*/
module dcord.client;

import std.stdio;

public import std.experimental.logger;

import std.algorithm.iteration, std.array;

import dcord.api,
       dcord.types,
       dcord.state,
       dcord.gateway,
       dcord.util.emitter;


/**
  Struct containing configuration for Gateway sharding
*/
struct ShardInfo {
  /** The number of the current shard */
  ushort shard = 0;

  /** Total number of shards */
  ushort numShards = 1;
}

@JSONIgnore
class Client {
  /** Base log */
  Logger log;

  /** Bot Authentication token */
  string token;

  /** Configuration for sharding */
  ShardInfo* shardInfo;

  /** APIClient instance */
  APIClient api;

  /** GatewayClient instance */
  GatewayClient gw;

  /** State instance */
  State state;

  /** Emitter for gateway events */
  Emitter events;

  /** Initializer */
  this(string token, LogLevel lvl=LogLevel.all, ShardInfo* shardInfo = null) {
    this.log = new FileLogger(stdout, lvl);
    this.token = token;
    this.shardInfo = shardInfo ? shardInfo : new ShardInfo();

    this.api = new APIClient(this);
    this.gw = new GatewayClient(this);
    this.state = new State(this);
  }

  /**
    Returns the current user.
  */
  @property User me() {
    return this.state.me;
  }

  /**
    Gets an array of messages for a given channel.

    Params:
      channelID = the channelID all the messages originate from.
      limit = the number of messages to retrieve.
      msgID = the message which other messages are selected, with respect to the filter
      filter = get messages before, around, or after the supplied msgID
  */
  Message[] getMessages(Snowflake channelID, uint limit = 100, Snowflake msgID = 0, MessageFilter filter = MessageFilter.BEFORE) {
    return this.api.channelsMessagesList(channelID, limit, filter, msgID);
  }

  /**
    Deletes an array of messages for a given channel, properly bulking them
    if required.

    Params:
      channelID = the channelID all the messages originate from.
      messages = the array of messages.
  */
  void deleteMessages(Snowflake channelID, Message[] messages) {
    deleteMessages(channelID, messages.map!(m => m.id).array);
  }

  /**
    Deletes an array of message IDs for a given channel, properly bulking them
    if required.

    Params:
      channelID = the channelID all the messages originate from
      msgIDs = the array of message IDs
  */
  void deleteMessages(Snowflake channelID, Snowflake[] msgIDs) {
    if (msgIDs.length <= 2) {
      msgIDs.each!(x => this.api.channelsMessagesDelete(channelID, x));
    } else {
      this.api.channelsMessagesDeleteBulk(channelID, msgIDs);
    }
  }

}
