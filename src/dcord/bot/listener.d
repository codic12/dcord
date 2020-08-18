/**
  Utilties for handling/listening to events through the dcord bot interface.
*/

module dcord.bot.listener;

import std.variant,
       std.string,
       std.array;

import dcord.types,
       dcord.gateway,
       dcord.util.emitter;

/**
  UDA that can be used on a Plugin, informing it that the function will handle
  all events of type T.

  Params:
    T = Event type to listen for
*/
ListenerDef!T Listener(T, EmitterOrder order = EmitterOrder.UNSPECIFIED)() {
  return ListenerDef!(T)(T.stringof, order, (event, func) {
    func(event.get!(T));
  });
}

/**
  Utility struct returned by the UDA.
*/
struct ListenerDef(T) {
  string clsName;
  EmitterOrder order;
  void delegate(Variant, void delegate(T)) func;
}

/**
  A ListenerObject represents the configuration/state for a single listener.
*/
class ListenerObject {
  /** The class name of the event this listener is for */
  string  clsName;

  /// Emitter order for this event listener
  EmitterOrder order;

  /** EventListener function for this Listener */
  EventListener  listener;

  /** Utility variant caller for converting event type */
  void delegate(Variant v) func;

  this(string clsName, EmitterOrder order, void delegate(Variant v) func) {
    this.clsName = clsName;
    this.func = func;
  }
}

/**
  The Listenable template is a virtual implementation which handles the listener
  UDAs, storing them within a local "listeners" mapping.
*/
mixin template Listenable() {
  ListenerObject[]  listeners;

  void loadListeners(T)() {
    // TODO: make this cleaner 
    foreach (mem; __traits(allMembers, T)) {
      foreach(attr; __traits(getAttributes, __traits(getMember, T, mem))) {
        static if (__traits(hasMember, attr, "clsName")) {
          this.registerListener(new ListenerObject(attr.clsName, attr.order, (v) {
            attr.func(v, mixin("&(cast(T)this)." ~ mem));
          }));
        }
      }
    }
  }

  /**
    Registers a listener from a ListenerObject
  */
  void registerListener(ListenerObject obj) {
    this.listeners ~= obj;
  }
}
