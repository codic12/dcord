/// Provides collectors, like MessageCollector.
module dcord.types.collectors;

import dcord.bot.plugin, dcord.types, dcord.core, std.typecons, std.variant, std.stdio, std.conv;
import vibe.core.core;  

/// MessageCollector is a feature-complete message collector with timeouts, callbacks, and filters, inspired by Discord.js. It can be used for listening to user input in seperate messages 
class MessageCollector: Plugin {
  /// The channel the MessageCollector is for. Only listens to messages in this channel
  Channel chan;
  /// The callback to execute upon each message, as a delegate
  void delegate(Message) callback;
  /// Whether the MessageCollector is finished or not, used to track state internally
  bool done;
  /// The maximum amount of messages to listen to
  int cap;
  /// The number of messages listened to so far, used to track state internally
  long messagesSoFar;
  /// An array of messages which is appended to every time a message is recieved, provided to the ending callback when done
  Message[] messages;
  /// The time the collector should run for, represented as a Duration object. The collector ends, and calls the ending callback, when this time is up
  Nullable!(Duration) timeout;
  /// The time the collector should wait after a message. The collector ends, and calls the ending callback, when this time is up
  Nullable!(Duration) idleTimeout;
  /// A Vibe.d timer coresponding to the timeout variable, used to track timeout internally
  Nullable!(Timer) timeoutTimer;
  /// A Vibe.d Timer coresponding to the idleTimeout variable, used to track idle timeout internally - resetted after each message recieved
  Nullable!(Timer) idleTimeoutTimer;
  /// An optional (delegate) filter to check against; should return a bool, and take a Message; can be passed to the constructor. Example: `m => m.author.id == 1234567890`
  Nullable!(bool delegate(Message)) filter;
  /// The delegate to run when end() is called, passed to the Vibe.d timer upon creation; is @safe, but the delegate passed to onEnd does not need to be @safe, as it constructs a @trusted one from whatever's passed to it
  Nullable!(void delegate(Message[]) @safe) endCallback;

   /**
   Listen for message create events, internally. This is where the bulk of the logic is. Shouldn't be overloaded or overwritten
   Params:
    event = a MessageCreate event
  */
  @Listener!(MessageCreate, EmitterOrder.UNSPECIFIED)
  void onMessageCreate(MessageCreate event) {
    if(!this.done) { // only execute if the collector is not finished
      if(event.message.channel.id == this.chan.id) { // make sure that it's in the same channel
        if(event.message.author.id != event.message.client.state.me.id) { // bot responding to it's own message is a disaster
          if(!this.filter.isNull()) 
            if(!filter.get()(event.message)) return; // we can return early if it doesn't match the filter, if one exists.
          
          this.messages ~= event.message; 
          if(this.cap != 0) {
            if(this.messagesSoFar > this.cap) {
              end(this.messages);
            } else {
              this.messagesSoFar++;
            }
            if(this.messagesSoFar <= this.cap) {
              this.callback(event.message);
              if(!this.idleTimeoutTimer.isNull()) { // we only need to do this if the idle timeout timer exists (aka the idle timeout option was passed.
                  this.idleTimeoutTimer.get.stop(); // stop and reset the stopwatch
                  this.idleTimeoutTimer.get.rearm(this.idleTimeout.get); // start the stopwatch
              }
            }
          } else if(this.cap == 0) { // no cap
            this.callback(event.message);
          } else {
            throw new Error("The world is broken... your cap is neither equal to zero nor not equal to zero. This is probably a bug, please report it..");
          }
        }
      }
    }
  }

  /**
    Class constructor.
    Params:
      chan = a Channel object to listen for messages in
      filter = a filter delegate that accepts a message and returns a bool; defaults to null. Example: `m => m.author.id == 1234567890`
      opts = an associative array of options, with values being wrapped in the `Opts` type and keys being strings; defaults to null. Available options are: `cap`, `timeout`, and `idleTimeout`
  */
  this(Channel chan, bool delegate(Message) filter=null, Opts[string] opts=null) {
    // TODO: possible migration to `sumtype`
    this.chan = chan;
    if("cap" in opts) this.cap = *(opts["cap"].peek!int);
    else this.cap = 0;

    if("timeout" in opts) {
      this.timeout = *(opts["timeout"].peek!Duration);
      this.timeoutTimer = createTimer(delegate() @safe {
          try {
            this.end(this.messages);
          } catch(Exception t) { // stfu
            try this.trustedError(t); catch(Exception e) {} 
          }
        }); // create the timer 
      this.timeoutTimer.get.rearm(this.timeout.get); // arm the timer
    }

    if("idleTimeout" in opts) {
      this.idleTimeout = *(opts["idleTimeout"].peek!Duration);
      this.idleTimeoutTimer = createTimer(delegate() @safe {
        try {
          this.end(this.messages);
        } catch(Exception t) { // stfu
          try this.trustedError(t); catch(Exception e) {} 
        }
      }); // create the timer
      this.idleTimeoutTimer.get.rearm(this.idleTimeout.get); // arm the timer
    }
    this.filter = filter;
  }

  /**
    Class constructor.
    Params:
      chan = a Channel object to listen for messages in
      filter = a filter delegate that accepts a message and returns a bool; defaults to null. Example: `m => m.author.id == 1234567890`
  */
  this(Channel chan, bool delegate(Message) filter=null) {
    this.chan = chan;
    this.callback = callback;
    this.cap = 0; // == no cap
    this.filter = filter;
  }
  
  /**
    Set the callback to be run upon each message
    Params:
      callback = a void delegate(Message), assigned to this.callback
  */
  void onMessage(void delegate(Message) callback) {
    this.callback = callback;
  }

  /**
    Set the callback to be run at the end, when this.end() is called
    Params:
      callback = a void delegate(Message[]), assigned to this.callback; automatically wrapped in a @trusted delegate to stop Vibe.d from complaining that the callback isn't @safe 
  */
  void onEnd(void delegate(Message[]) callback) {
    this.endCallback = delegate(Message[] m) @trusted {
      callback(m);
    };
  }
  
  /**
    End the callback.
    Params:
      messages = an array of Message objects for the ending callback; these are stored in this.messages
  */
  void end(Message[] messages) @trusted {
    this.done = true;
    if(!this.endCallback.isNull()) this.endCallback.get()(messages); 
  }

  /// Simulate throwing an error by writing to stderr, but as a @trusted function that can be called within @safe functions. Used in ending callback; Vibe.d expects this to be a `nothrow @safe` delegate, internally
  private void trustedError(T...)(T args) @trusted {
    stderr.writeln(args);
  }
}