-module(sara_ffi).
-export([elapsed/1, exit/1]).

elapsed(Fun) ->
    Start = erlang:monotonic_time(),
    Return = Fun(),
    Stop = erlang:monotonic_time(),
    Elapsed = float(erlang:convert_time_unit(Stop - Start, native, nanosecond)),

    {Return, Elapsed}.

exit(N) ->
    halt(N).
