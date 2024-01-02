-module(clock). 
-export([start/1, get/1, startT/1, clock/3, clockTicker/3, ticker/2, startTicker/2, timer/3, startTimer/3, startTimer/2, timerDone/0, getTimer/1]).

% clockWrong(Speed, Pause, Time) -> 
%     receive
%         {set, Value} -> clock(Speed, Pause, Value);
%         {get, Pid} -> 
%             Pid!{clock, Time},
%             case Pause of
%                 true -> clock(Speed, Pause, Time);
%                 false -> clock(Speed, Pause, Time + 1)
%             end.
%         pause -> clock(Speed, true, Time);
%         resume -> clock(Speed, false, Time + 1);
%         stop -> ok
%     end.

clock(Speed, Pause, Time) -> 
    receive
        {set, Value} -> clock(Speed, Pause, Value);
        {get, Pid} -> Pid!{clock, Time}, clock(Speed, Pause, Time);
        pause -> clock(Speed, true, Time);
        resume -> clock(Speed, false, Time);
        stop -> ok
        %Nachteil receive after hier zu nutzen:
        %Beeinflussung des Increment-Verhaltens durch Erhalt anderer Nachrichten.
        %Außerdem Zeitverzögerung bei der Bearbeitung von Nachrichten durch den Prozess.
        after Speed ->
            case Pause of
                true -> clock(Speed, Pause, Time);
                false -> clock(Speed, Pause, Time + 1)
            end
    end.

clockTicker(TPid, Pause, Time) -> 
    %io:format("ClockTicker ~p", [self()]),
    receive
        {set, Value} -> clockTicker(TPid, Pause, Value);
        {get, Pid} -> Pid!{clock, Time}, clockTicker(TPid, Pause, Time);
        pause -> clockTicker(TPid, true, Time);
        resume -> clockTicker(TPid, false, Time);
        stop -> ok;
        {setTicker, Pid} ->
            case TPid of
                undefined -> clockTicker(Pid, Pause, Time);
                _ -> clockTicker(TPid, Pause, Time)
            end;
        %Durch TPid garantiert, dass nur der eigene Ticker-Subprozess beachtet wird.
        {tick, TPid} -> 
            case Pause of
                true -> clockTicker(TPid, Pause, Time);
                false -> clockTicker(TPid, Pause, Time + 1)
            end
    end.

ticker(Speed, Pid) ->
    receive
        stop -> ok
        after Speed ->
            Pid!{tick, self()},
            ticker(Speed, Pid)
    end.

startTicker(Speed, Pid) -> spawn(?MODULE, ticker, [Speed, Pid]).
start(Speed) -> spawn(?MODULE, clock, [Speed, false, 0]).
%startT(Speed) -> CT = spawn(?MODULE, clockTicker, [startTicker(Speed, CT), true, 0]), CT.
startT(Speed) -> io:format("Main ~p", [self()]), CT = spawn(?MODULE, clockTicker, [undefined, false, 0]),timer:sleep(2000), T = startTicker(Speed, CT), io:format("Ticker ~p", [T]), CT!{setTicker, T}, CT.

get(Pid) ->
    Pid!{get, self()},
    receive {clock, Value} -> Value end.


timer(TPid, Time, Func) ->
    receive
        {get, Pid} -> Pid!{timerI, Time}, timer(TPid, Time, Func);
        stop -> ok;
        {setTicker, Pid} ->
            case TPid of
                undefined -> timer(Pid, Time, Func);
                _ -> timer(TPid, Time, Func)
            end;
        {tick, TPid} -> 
            case Time - 1 of
                0 -> Func();
                _ -> timer(TPid, Time - 1, Func)
            end
    end.

startTimer(Speed, Time, Func) -> CT = spawn(?MODULE, timer, [undefined, Time, Func]), T = startTicker(Speed, CT), CT!{setTicker, T}, CT.
%startTimer(Speed, Time) -> CT = spawn(?MODULE, timer, [undefined, Time, timerDone]), T = startTicker(Speed, CT), CT!{setTicker, T}, CT.   %Geht so nicht!

timerDone() -> io:format("Timer ist fertig!\n").
%func1 = fun io:format("Timer ist fertig!") end.

% Für den korrekten Aufruf in der Konsole: A = clock:startTimer(10, 1000, fun clock:timerDone/0).

getTimer(Pid) ->
    Pid!{get, self()},
    receive {timerI, Value} -> Value end.

