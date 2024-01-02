-module(clock). 
-export([start/1, get/1, startT/1, startTicker/2, timer/3, startTimer/3, timerDone/0, getTimer/1]).

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
    receive
        {set, Value} -> clock(TPid, Pause, Value);
        {get, Pid} -> Pid!{clock, Time}, clock(TPid, Pause, Time);
        pause -> clock(TPid, true, Time);
        resume -> clock(TPid, false, Time);
        stop -> ok;
        {setTicker, Pid} ->
            case TPid of
                undefined -> clockTicker(Pid, Pause, Time);
                _ -> clockTicker(TPid, Pause, Time)
            end;
        %Durch TPid garantiert, dass nur der eigene Ticker-Subprozess beachtet wird.
        {tick, TPid} -> 
            case Pause of
                true -> clock(TPid, Pause, Time);
                false -> clock(TPid, Pause, Time + 1)
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
startT(Speed) -> CT = spawn(?MODULE, clockTicker, [undefined, true, 0]),timer:sleep(100) , CT!{setTicker, startTicker(Speed, CT)}.

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

startTimer(Speed, Time, Func) -> CT = spawn(?MODULE, timer, [undefined, Time, Func]), timer:sleep(100), CT!{setTicker, startTicker(Speed, CT)}.

timerDone() -> "Timer ist fertig!".

getTimer(Pid) ->
    Pid!{get, self()},
    receive {timerI, Value} -> Value end.



%register(globalClock, start, [10]).