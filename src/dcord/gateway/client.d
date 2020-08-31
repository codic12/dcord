/**
  Manages the Discord websocket client.
*/
module dcord.gateway.client;

import std.stdio,
       std.uni,
       std.functional,
       std.zlib,
       std.datetime,
       std.variant,
       std.format,
       core.exception,
       core.memory;

static import std.typecons;

import vibe.core.core,
       vibe.inet.url,
       vibe.http.websockets;

import dcord.client,
       dcord.gateway,
       dcord.util.emitter,
       dcord.util.json,
       dcord.util.counter,
       dcord.types;

/** Maximum reconnects the GatewayClient will try before resetting session state */
const ubyte MAX_RECONNECTS = 6;

/** Current implemented Gateway version. */
const ubyte GATEWAY_VERSION = 6;
/**
  GatewayClient is the base abstraction for connecting to, and interacting with
  the Discord Websocket (gateway) API.
*/
class GatewayClient {
  /** Client instance for this gateway connection */
  Client client;

  /** WebSocket connection for this gateway connection */
  WebSocket sock;

  /** Gateway SessionID, used for resuming. */
  string sessionID;

  /** Gateway sequence number, used for resuming */
  uint seq;

  /** Heartbeat interval */
  uint heartbeatInterval;

  /** Whether this GatewayClient is currently connected */
  bool connected;

  /** Number of reconnects attempted */
  ubyte reconnects;

  /** The heartbeater task */
  Task heartbeater;

  /** Event emitter for Gateway Packets */
  Emitter eventEmitter;

  private {
    /** Cached gateway URL from the API */
    string cachedGatewayURL;
    Counter!string eventCounter;
    bool eventTracking;
  }

  /**
    Params:
      client = base client
      eventTracking = if true, log information about events recieved
  */
  this(Client client, bool eventTracking = false) {
    this.client = client;
    this.eventTracking = eventTracking;

    // Create the event emitter and listen to some required gateway events.
    this.eventEmitter = new Emitter;
    this.eventEmitter.listen!Ready(toDelegate(&this.handleReadyEvent));
    this.eventEmitter.listen!Resumed(toDelegate(&this.handleResumedEvent));

    // Copy emitters to client for easier API access
    client.events = this.eventEmitter;

    if (this.eventTracking) this.eventCounter = new Counter!string;
  }

  /**
    Logger for this GatewayClient.
  */
  @property Logger log() {
    return this.client.log;
  }

  /**
    Starts a connection to the gateway. Also called for resuming/reconnecting.
  */
  void start(Game game=null) {
    if(this.sock && this.sock.connected) this.sock.close();

    // If this is our first connection, get a gateway websocket URL. Later on it is cached.
    if(!this.cachedGatewayURL) {
      this.cachedGatewayURL = client.api.gatewayGet();
      this.cachedGatewayURL ~= format("/?v=%s&encoding=%s", GATEWAY_VERSION, "json");
    }

    // Start the main task
    this.log.infof("Starting connection to Gateway WebSocket (%s)", this.cachedGatewayURL);
    this.sock = connectWebSocket(URL(this.cachedGatewayURL));
    if(game is null) runTask(() => this.run());
    else runTask(() => this.run(game));
  }

  /**
    Send a gateway payload.
  */
  void send(Serializable p) {
    string data = p.serialize().toString;
    version (DEBUG_GATEWAY_DATA) {
      this.log.tracef("GATEWAY SEND: %s", data);
    }
    this.sock.send(data);
  }

  void updateStatus(Game game=null) {
    this.send(new StatusUpdate(game));
  }
  private void debugEventCounts() {
    while (true) {
      this.eventCounter.resetAll();
      sleep(5.seconds);
      this.log.infof("%s total events", this.eventCounter.total);

      foreach (ref event; this.eventCounter.mostCommon(5)) {
        this.log.infof("  %s: %s", event, this.eventCounter.get(event));
      }
    }
  }

  private void handleReadyEvent(Ready  r) {
    this.log.infof("Recieved READY payload, starting heartbeater");
    // this.hb_interval = r.heartbeatInterval;
    this.sessionID = r.sessionID;
    this.reconnects = 0;

    if (this.eventTracking) {
      runTask(toDelegate(&this.debugEventCounts));
    }
  }

  private void handleResumedEvent(Resumed r) { // stfu
    this.heartbeater = runTask(toDelegate(&this.heartbeat));
    // TODO: do an action in a closure with the Resumed event
  }

  private void emitDispatchEvent(T)(VibeJSON obj) {
    T v = new T(this.client, obj["d"]);
    this.eventEmitter.emit!T(v);
    v.resolveDeferreds();
  }

  private void handleDispatchPacket(VibeJSON obj, size_t size) {
    // Update sequence number if it's larger than what we have
    uint seq = obj["s"].get!uint; // stfu
    if (seq > this.seq) {
      this.seq = seq;
    }

    string type = obj["t"].get!string;

    if (this.eventTracking) {
      this.eventCounter.tick(type);
    }

    switch (type) {
      case "READY":
        this.log.infof("Recieved READY payload, size in bytes: %s", size);
        this.emitDispatchEvent!Ready(obj);
        break;
      case "RESUMED":
        this.emitDispatchEvent!Resumed(obj);
        break;
      case "CHANNEL_CREATE":
        this.emitDispatchEvent!ChannelCreate(obj);
        break;
      case "CHANNEL_UPDATE":
        this.emitDispatchEvent!ChannelUpdate(obj);
        break;
      case "CHANNEL_DELETE":
        this.emitDispatchEvent!ChannelDelete(obj);
        break;
      case "GUILD_BAN_ADD":
        this.emitDispatchEvent!GuildBanAdd(obj);
        break;
      case "GUILD_BAN_REMOVE":
        this.emitDispatchEvent!GuildBanRemove(obj);
        break;
      case "GUILD_CREATE":
        this.emitDispatchEvent!GuildCreate(obj);
        break;
      case "GUILD_UPDATE":
        this.emitDispatchEvent!GuildUpdate(obj);
        break;
      case "GUILD_DELETE":
        this.emitDispatchEvent!GuildDelete(obj);
        break;
      case "GUILD_EMOJIS_UPDATE":
        this.emitDispatchEvent!GuildEmojisUpdate(obj);
        break;
      case "GUILD_INTEGRATIONS_UPDATE":
        this.emitDispatchEvent!GuildIntegrationsUpdate(obj);
        break;
      case "GUILD_MEMBERS_CHUNK":
        this.emitDispatchEvent!GuildMembersChunk(obj);
        break;
      case "GUILD_MEMBER_ADD":
        this.emitDispatchEvent!GuildMemberAdd(obj);
        break;
      case "GUILD_MEMBER_UPDATE":
        this.emitDispatchEvent!GuildMemberUpdate(obj);
        break;
      case "GUILD_MEMBER_REMOVE":
        this.emitDispatchEvent!GuildMemberRemove(obj);
        break;
      case "GUILD_ROLE_CREATE":
        this.emitDispatchEvent!GuildRoleCreate(obj);
        break;
      case "GUILD_ROLE_UPDATE":
        this.emitDispatchEvent!GuildRoleUpdate(obj);
        break;
      case "GUILD_ROLE_DELETE":
        this.emitDispatchEvent!GuildRoleDelete(obj);
        break;
      case "MESSAGE_CREATE":
        this.emitDispatchEvent!MessageCreate(obj);
        break;
      case "MESSAGE_UPDATE":
        this.emitDispatchEvent!MessageUpdate(obj);
        break;
      case "MESSAGE_DELETE":
        this.emitDispatchEvent!MessageDelete(obj);
        break;
      case "PRESENCE_UPDATE":
        this.emitDispatchEvent!PresenceUpdate(obj);
        break;
      case "TYPING_START":
        this.emitDispatchEvent!TypingStart(obj);
        break;
      case "USER_SETTINGS_UPDATE":
        this.emitDispatchEvent!UserSettingsUpdate(obj);
        break;
      case "USER_UPDATE":
        this.emitDispatchEvent!UserUpdate(obj);
        break;
      case "VOICE_STATE_UPDATE":
        this.emitDispatchEvent!VoiceStateUpdate(obj);
        break;
      case "VOICE_SERVER_UPDATE":
        this.emitDispatchEvent!VoiceServerUpdate(obj);
        break;
      case "CHANNEL_PINS_UPDATE":
        this.emitDispatchEvent!ChannelPinsUpdate(obj);
        break;
      case "MESSAGE_DELETE_BULK":
        this.emitDispatchEvent!MessageDeleteBulk(obj);
        break;
      case "MESSAGE_REACTION_ADD":
        this.emitDispatchEvent!MessageReactionAdd(obj);
        break;
      default:
        this.log.warningf("Unhandled dispatch event: %s", type);
        break;
    }
  }

  private void parse(string rawData) {
    GC.disable; // because GC messes stuff up
    VibeJSON json = parseJsonString(rawData);

    version (DEBUG_GATEWAY_DATA) {
    }

    OPCode op = json["op"].get!OPCode;
    switch (op) {
      case OPCode.DISPATCH:
        this.handleDispatchPacket(json, rawData.length);
        break;
      case OPCode.HEARTBEAT:
        this.send(new HeartbeatPacket(this.seq));
        break;
      case OPCode.RECONNECT:
        this.log.warningf("Recieved RECONNECT OPCode, resetting connection...");
        if (this.sock && this.sock.connected) this.sock.close();
        break;
      case OPCode.INVALID_SESSION:
        this.log.warningf("Recieved INVALID_SESSION OPCode, resetting connection...");
        if (this.sock && this.sock.connected) this.sock.close();
        break;
      case OPCode.HELLO:
        this.log.tracef("Recieved HELLO OPCode, starting heartbeater...");
        this.heartbeatInterval = json["d"]["heartbeat_interval"].get!uint;
        this.heartbeater = runTask(toDelegate(&this.heartbeat));
        break;
      case OPCode.HEARTBEAT_ACK:
        break;
      default:
        this.log.warningf("Unhandled gateway packet: %s", op);
        break;
    }
  }

  private void heartbeat() {
    while(this.connected) {
      this.send(new HeartbeatPacket(this.seq));
      sleep(this.heartbeatInterval.msecs);
    }
  }

  /// Runs the GatewayClient until completion 
  void run(Game game=null) {
    string data;

    // If we already have a sequence number, attempt to resume
    if(this.sessionID && this.seq) {
      this.log.infof("Sending resume payload (session ID %s with gateway sequence number %s)",
      this.sessionID, this.seq);
      
      this.send(new ResumePacket(this.client.token, this.sessionID, this.seq));
    } else {
      // On startup, send the identify payload
      this.log.info("Sending identify payload");
      this.send(new IdentifyPacket(
          this.client.token,
          this.client.shardInfo.shard,
          this.client.shardInfo.numShards));
    }

    this.log.info("Connected to Gateway");
    this.connected = true;
    this.send(new StatusUpdate(game));
    while (this.sock.waitForData()) {
      if(!this.connected) break;
      try {
        ubyte[] rawdata = this.sock.receiveBinary();
        data = cast(string)uncompress(rawdata); // raw cast could be dangerous - maybe use toString in the future 
      } catch (Exception e) {
        data = this.sock.receiveText();
      }
      if(data == "") continue; 

      try {
        this.parse(data);
      } catch(Exception e) {
        this.log.warningf("failed to handle data (%s)", e);
      } catch(Error e) { // stfu
        this.log.warningf("failed to handle data (%s)", e);
      } 
    }

    this.log.critical("Gateway websocket closed (code " ~ this.sock.closeCode().toString() ~ ")");
    this.connected = false;
    this.reconnects++;

    if(this.reconnects > MAX_RECONNECTS) {
      this.log.errorf("Max Gateway reconnects (%s) hit, aborting...", this.reconnects);
      return;
    }

    if(this.reconnects > 1) {
      this.sessionID = null;
      this.seq = 0;
      this.log.warning("Waiting 5 seconds before reconnecting...");
      sleep(5.seconds);
    }

    this.log.info("Attempting reconnection...");
    return this.start();
  }
}
