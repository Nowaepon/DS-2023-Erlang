-module(bully).
-compile(export_all).
%-compile([sendNewCoordinator/3, sendElections/2, bullyProcess/2, beginElection/3, waitForNewCoordinator/1, setup/1, setupIntern/2, setupInternStartup/3]).


%Zum Senden der coordinator-Nachrichten an alle Prozesse außer sich selbst und den alten Coordinator
sendNewCoordinator(_, _, []) -> ok;
sendNewCoordinator(NewCoordPID, OldCoordPID, [LastPID]) ->
    case LastPID of
        NewCoordPID -> ok;
        OldCoordPID -> ok;
        _ -> LastPID!{coordinator, NewCoordPID}
    end;
sendNewCoordinator(NewCoordPID, OldCoordPID, [FirstPID|OtherPIDs]) -> 
    case FirstPID of
        NewCoordPID -> sendNewCoordinator(NewCoordPID, OldCoordPID, OtherPIDs);
        OldCoordPID -> sendNewCoordinator(NewCoordPID, OldCoordPID, OtherPIDs);
        _ -> FirstPID!{coordinator, NewCoordPID},
            sendNewCoordinator(NewCoordPID, OldCoordPID, OtherPIDs)
    end.


%Zum Senden der Election-Nachrichten an alle höheren PIDs
sendElections(_, [], _) -> ok;
sendElections(OwnerPID, [LastPID], CountPID) -> 
    case OwnerPID < LastPID of
        true -> LastPID!{election, OwnerPID}, CountPID!{election, OwnerPID}
    end;
sendElections(OwnerPID, [FirstPID|OtherPIDs], CountPID) ->
    case OwnerPID < FirstPID of
        true -> FirstPID!{election, OwnerPID}, CountPID!{election, OwnerPID}, sendElections(OwnerPID, OtherPIDs, CountPID);
        false -> sendElections(OwnerPID, OtherPIDs, CountPID)
    end.

% Zur Intitialisierung der Prozesse nötig
bullyProcess(undefined, undefined, CountPID) ->
    receive
        {startup, CoordPID, OtherPIDs} -> bullyProcess(CoordPID, OtherPIDs, CountPID)
    end;
bullyProcess(CoordPID, OtherPIDs, CountPID) ->
    if 
        %Bin ich selbst der Coordinator? Dann muss ich auf rpcs antworten
        CoordPID == self() ->
            receive
                {PID, request} -> PID!{self(), response}, bullyProcess(CoordPID, OtherPIDs, CountPID)
            end;
        %Andernfalls überprüfe, ob der Coordinator erreichbar ist.
        %Wenn ja, alles gut, und wiederhole die Prüfung (Intervall oder so wegen Nachrichtenspam?).
        %Wenn nein, starte eine Election.
        true ->
            CoordPID!{self(), request},
            receive
                {_ , response} -> bullyProcess(CoordPID, OtherPIDs, CountPID);
                startElection -> beginElection(self(), CoordPID, OtherPIDs, CountPID);
            %TODO: Müssen wir election-Nachrichten von neuen prozessen beachten und in OtherPIDs einfügen?
                {election, SenderPid} -> 
                    SenderPid!ok,
                    beginElection(self(), CoordPID, OtherPIDs, CountPID)
                after 250 ->
                    %Starte Election
                    beginElection(self(), CoordPID, OtherPIDs, CountPID)
                    %bullyProcess(self(), OtherPIDs, CountPID)
            end
    end.

%Beginnt damit, eine Election auszuführen
beginElection(OwnPID, OldCoordPID, OtherPIDs, CountPID) ->
    sendElections(OwnPID, OtherPIDs, CountPID),

    receive
        ok -> waitForNewCoordinator(OtherPIDs, CountPID)
        after 250 ->
            %Dann bin ich selbst coordinator
            sendNewCoordinator(OwnPID, OldCoordPID, OtherPIDs),
            bullyProcess(OwnPID, OtherPIDs, CountPID)
    end.

%Damit mehrere ok-Nachrichten auch alle aufgebraucht werden und nicht in der Messagebox verbleiben
%Wie abzufangen, wenn letztes ok nach coordinator kommt?
waitForNewCoordinator(OtherPIDs, CountPID) ->
    receive
        {coordinator, NewCoordPID} -> bullyProcess(NewCoordPID, OtherPIDs, CountPID);
        ok -> waitForNewCoordinator(OtherPIDs, CountPID)
    end.

%Aufgabenteil b)
%Beliebige Menge an Prozessen startbar, Liste aller Prozesse wird zurückgegeben
setup(Amount) -> setupIntern(Amount, [], spawn(?MODULE, counter, [0])).

%Erstelle erst alle Prozesse, bevor ihre Logik selbst startet
setupIntern(0, [], _) -> done;
setupIntern(0, ListPIDs, _) -> setupInternStartup(lists:max(ListPIDs), ListPIDs, ListPIDs);
setupIntern(Amount, ListPIDs, CountPID) ->
    A = spawn(?MODULE, bullyProcess, [undefined, undefined, CountPID]),
    setupIntern(Amount - 1, lists:append(ListPIDs, [A]), CountPID).

%Starte die Logik aller Prozesse, indem ihnen der Initial-Koordinator und die anderen Prozesse bekannt gemacht werden.
%setupInternStartup(coordPID, allPIDs, []) -> darfNichtVorkommen.
setupInternStartup(_, AllPIDs, []) -> AllPIDs;
setupInternStartup(CoordPID, AllPIDs, [LastPID]) ->
    LastPID!{startup, CoordPID, lists:filter(fun(X) -> X /= LastPID end, AllPIDs)},
    setupInternStartup(CoordPID, AllPIDs, []);
setupInternStartup(CoordPID, AllPIDs, [FirstPID|OtherPIDs]) -> 
    FilteredList = lists:filter(fun(X) -> X /= FirstPID end, AllPIDs),
    FirstPID!{startup, CoordPID, FilteredList},
    setupInternStartup(CoordPID, AllPIDs, OtherPIDs).

startElectionFromCLI(ProcessList, Index) ->
    lists:nth(Index, ProcessList)!startElection.

%startElectionFromCLI2(ProcessList) ->
%    lists:min(ProcessList)!startElection.

counter(Count) ->
    io:format("Counter Value: ~p\n", [Count]),
    receive
        {election, _} -> counter(Count + 1) 
    end.