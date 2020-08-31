/// Provides several type unions 
module dcord.types.opts;
import std.variant, core.time;

/*
    Opts provides an Algebraic type union used for options in associative arrays. It can be constructed by wrapping a supported type in Opts(), eg `["a": Opts(5), "b": Opts(1.seconds)`, and currently supports signed integers and Duration objects
*/
alias Opts = Algebraic!(int, Duration); // add more when needed
