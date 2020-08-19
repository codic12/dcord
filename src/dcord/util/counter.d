/**
  Utility class for keeping a count of items
*/
module dcord.util.counter;

import std.algorithm;

/// Counter is a utility class to keep a count of items
class Counter(T) {
  /// The total amount of items
  uint total;
  /// The associative array with the actual data
  uint[T] storage;
  
  /// Get an element from storage
  uint get(T v) {
    return this.storage[v];
  }

  /// Increment the total amount of items, and the specified item, by one 
  void tick(T v) {
    this.total += 1;
    this.storage[v] += 1;
  }

  /// Reset the count of an element
  void reset(T v) {
    this.total -= this.storage[v];
    this.storage[v] = 0;
  }
  
  /// Reset the count of all elements
  void resetAll() {
    foreach (ref k; this.storage.keys) {
      this.reset(k);
    }
    this.total = 0;
  }
  /**
    Find the most common item, using a schwartz sorting algorithm.
    Params:
      limit = the limit of items
  */
  auto mostCommon(uint limit) {
    auto res = schwartzSort!(k => this.storage[k], "a > b")(this.storage.keys);
    if (res.length > limit) {
      return res[0..limit];
    } else {
      return res;
    }
  }
}
