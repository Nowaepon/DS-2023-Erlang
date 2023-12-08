% Aufgabe 1

-module(ex7). 
-export([convert/2, maxitem/1, diff3/3]). 

convert(Amount, inch) -> {"cm", Amount * 2.54};
convert(Amount, cm) -> {"inch", Amount / 2.54}.


% ACHTUNG !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!     VARIABLENNAMEN MUESSEN GROSS GESCHRIEBEN WERDEN !?=*!!!!


%11> ex7:convert(30, miles).
%** exception error: no function clause matching ex7:convert(30,miles) (ex7.erl, line 6)
% Es ist ja keine Definition für diesen Fall angelegt.


maxitem(List) ->
    case List of
        [] -> io:format("Reached the end of the list. Returning 0.~n", []), 0;
        [X | []] -> io:format("One element in the list. Returning this element: ~p~n", [X]), X;
        %Offenbar cacht Erlang das Ergebnis von maxitem(Xs) nicht, anders als Haskell ... Wow. Performance aus der Hoelle.
        [X | Xs] -> io:format("Comparing elements ~p and ~p.~n", [X, maxitem(Xs)]), case maxitem(Xs) > X of
                        true -> maxitem(Xs);
                        false -> X
                    end
        %[X | Xs] -> if maxitem(Xs) > X -> maxitem(Xs); true -> X end
    end.


% Aus der offiziellen Erlang-Implementierung
max2([X|Xs]) -> max2(Xs, X).

max2([X|Xs], Max) when X > Max -> max2(Xs, X);
max2([_|Xs], Max)              -> max2(Xs, Max);
max2([],    Max)              -> Max.



diff3(F, X, H) -> (F(X + H) - F(X - H)) / (2 * H).

%F = fun(X) -> 2 * X * X * X - 12 * X + 3 end.

%65> ex7:diff3(F, 3, 1.0e-10).                    
%42.00000347509558




%maxitem(List) when List == [] -> 0;
%maxitem(List) when List == [x | xs] -> maxitem(xs, x).
%maxitem([]) -> 0;
%maxitem([x | xs]) -> 1.% maxitem2(xs, x).

%maxitem(List) when List == [] -> 0;
%maxitem(List) when List == [x | []] -> x;
%maxitem(List) when List == [x | xs] -> maxitem(xs).


%maxitem(List) ->
%    case List of
%        [] -> 0;
%        [_ | []] -> 1;
%        [H1, H2 | _] ->
%            if
%                maxitem([H1, H2]) > CurrentMax ->
%                    maxitem(tl(List));
%                true ->
%                    CurrentMax
%            end
%    end.

%maxitem(List) ->
%    case List of
%        [] -> 0;
%        [x | xs] -> 1
%    end.

%    case List of
%        [] -> 0;
%        [x | xs] -> maxitem(xs, x)
%    end.

%maxitem2([], Max) -> Max;
%maxitem2([x | xs], Max) when x > Max -> 
%    maxitem2(xs, x);
%maxitem2([_ | xs], Max) -> 
%    maxitem2(xs, Max).


