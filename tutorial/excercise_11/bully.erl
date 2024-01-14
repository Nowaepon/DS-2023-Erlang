-module(bully).
-compile().


%Zum Senden der Election-Nachrichten an alle höheren PIDs
sendElections(ownerPID, []) -> ok.
sendElections(ownerPID, [lastPID]) -> 
    case ownerPID < lastPID of
        true -> lastPID!election
sendElections(ownerPID, [firstPID|otherPIDs]) ->
    case ownerPID < firstPID of
        true -> firstPID!election, sendElections(ownerPID, otherPIDs);
        false -> sendElections(ownerPID, otherPIDs)
    end.

% Zur Intitialisierung der Processes nötig
bullyProcess(undefined, undefined) ->
    receive
        {startup, coordPID, otherPIDs} -> bullyProcess(coordPID, otherPIDs)

%TODO: Noch unvollständig, ABlauflogik nicht klar
%      Noch gar nicht beachtet ist, wenn man selbst election Nachrichten erhält, während man gerade auf z. B. den rpc wartet.
bullyProcess(coordPID, otherPIDs) ->
    if 
        %Bin ich selbst der Coordinator? Dann muss ich auf rpcs antworten
        coordPID == self() ->
            receive
                {PID, Request} -> PID!response, bullyProcess(coordPID, otherPIDs)
            end
        %Anernfalls überprüfe, ob der Coordinator erreichbar ist.
        %Wenn ja, alles gut, und wiederhole die Prüfung (Intervall oder so wegen Nachrichtenspam?).
        %Wenn nein, starte eine Election.
        true ->
            if
                rpc:rpc(coordPID, request) == response -> bullyProcess(coordPID, otherPIDs)
                true -> 

            receive
                election -> ;
                coordinator -> ;
    .

%Aufgabenteil b)
%Beliebige Menge an Prozessen startbar, Liste aller Prozesse wird zurückgegeben
setup(Amount) -> setupIntern(Amount, [])

%Erstelle erst alle Prozesse, bevor ihre Logik selbst startet
%setupIntern(0, []) -> done.
setupIntern(0, ListPIDs) -> setupInternStartup(lists:max(ListPIDs), ListPIDs, ListPIDs).
setupIntern(Amount, ListPIDs) ->
    A = spawn(?MODULE, bullyProcess, [undefined, undefined]),
    setupIntern(Amount - 1, lists:append(ListPIDs, [A]).

%Starte die Logik aller Prozesse, indem ihnen der Initial-Koordinator und die anderen Prozesse bekannt gemacht werden.
%setupInternStartup(coordPID, allPIDs, []) -> darfNichtVorkommen.
setupInternStartup(coordPID, allPIDs, []) -> allPIDs.
setupInternStartup(coordPID, allPIDs, [lastPID]) ->
    lastPID!{startup, coordPID, lists:filter(fun(X) -> X /= lastPID end, allPIDs)},
    setupInternStartup(coordPID, allPIDs, []).
setupInternStartup(coordPID, allPIDs, [firstPID|otherPIDs]) -> 
    lastPID!{startup, coordPID, lists:filter(fun(X) -> X /= lastPID end, allPIDs)},
    setupInternStartup(coordPID, allPIDs, otherPIDs).

