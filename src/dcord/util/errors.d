/**
  Utilities related to errors and exceptions
*/
module dcord.util.errors;

import std.format;

/// Simple exception mixin for creating custom exceptions.
public mixin template ExceptionMixin() {
  this(string msg = null, Throwable next = null) { super(msg, next); }
  this(string msg, string file, size_t line, Throwable next = null) {
    super(msg, file, line, next);
  }
}

/// Base class for Dcord errors
class BaseError: Exception {
  this(T...)(string msg, T args) {
    super(format(msg, args));
  }
}
