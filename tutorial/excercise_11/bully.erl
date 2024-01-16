-module(bully).
-compile([sendNewCoordinator/3, sendElections/2, bullyProcess/2, beginElection/3, waitForNewCoordinator/1, setup/1, setupIntern/2, setupInternStartup/3]).


%Zum Senden der coordinator-Nachrichten an alle Prozesse außer sich selbst und den alten Coordinator
sendNewCoordinator(_, _, []) -> ok;
sendNewCoordinator(NewCoordPID, OldCoordPID, [LastPID]) -> 
    case LastPID of
        NewCoordPID -> ok;
        OldCoordPID -> ok;
        true -> LastPID!{coordinator, NewCoordPID}
    end;
sendNewCoordinator(NewCoordPID, OldCoordPID, [FirstPID|OtherPIDs]) -> 
    case FirstPID of
        NewCoordPID -> sendNewCoordinator(NewCoordPID, OldCoordPID, OtherPIDs);
        OldCoordPID -> sendNewCoordinator(NewCoordPID, OldCoordPID, OtherPIDs);
        true -> FirstPID!{coordinator, NewCoordPID}
    end.


%Zum Senden der Election-Nachrichten an alle höheren PIDs
sendElections(_, []) -> ok;
sendElections(OwnerPID, [LastPID]) -> 
    case OwnerPID < LastPID of
        true -> LastPID!{election, OwnerPID}
    end;
sendElections(OwnerPID, [FirstPID|OtherPIDs]) ->
    case OwnerPID < FirstPID of
        true -> FirstPID!{election, OwnerPID}, sendElections(OwnerPID, OtherPIDs);
        false -> sendElections(OwnerPID, OtherPIDs)
    end.

% Zur Intitialisierung der Prozesse nötig
bullyProcess(undefined, undefined) ->
    receive
        {startup, CoordPID, OtherPIDs} -> bullyProcess(CoordPID, OtherPIDs)
    end;
bullyProcess(CoordPID, OtherPIDs) ->
    if 
        %Bin ich selbst der Coordinator? Dann muss ich auf rpcs antworten
        CoordPID == self() ->
            receive
                {PID, request} -> PID!{self(), response}, bullyProcess(CoordPID, OtherPIDs)
            % TODO: Irgendwie auf election eingehen?
            end;
        %Andernfalls überprüfe, ob der Coordinator erreichbar ist.
        %Wenn ja, alles gut, und wiederhole die Prüfung (Intervall oder so wegen Nachrichtenspam?).
        %Wenn nein, starte eine Election.
        true ->
            CoordPID!{self(), request},
            receive
                {_ , response} -> bullyProcess(CoordPID, OtherPIDs);
                startElection -> beginElection(self(), CoordPID, OtherPIDs);
            %TODO: Müssen wir election-Nachrichten von neuen prozessen beachten und in OtherPIDs einfügen?
                {election, SenderPid} -> 
                    SenderPid!ok,
                    %TODO: Hier stimmt noch was nicht
                    receive
                        {coordinator, NewCoordPID} -> beginElection(self(), CoordPID, OtherPIDs)
                    end
                after 250 ->
                    %Starte Election
                    beginElection(self(), CoordPID, OtherPIDs)

                    % sendElections(self(), OtherPIDs)

                    % receive
                    %     ok -> waitForNewCoordinator(OtherPIDs)
                    % after 250
                    %     %Dann bin ich selbst coordinator
                    %     sendNewCoordinator(self(), CoordPID, OtherPIDs);
                    % end
            end
    end.

%Beginnt damit, eine Election auszuführen
beginElection(OwnPID, OldCoordPID, OtherPIDs) ->
    sendElections(OwnPID, OtherPIDs),

    receive
        ok -> waitForNewCoordinator(OtherPIDs)
        after 250 ->
            %Dann bin ich selbst coordinator
            sendNewCoordinator(self(), OldCoordPID, OtherPIDs)
    end.

%Damit mehrere ok-Nachrichten auch alle aufgebraucht werden und nicht in der Messagebox verbleiben
%Wie abzufangen, wenn letztes ok nach coordinator kommt?
waitForNewCoordinator(OtherPIDs) ->
    receive
        {coordinator, NewCoordPID} -> bullyProcess(NewCoordPID, OtherPIDs);
        ok -> waitForNewCoordinator(OtherPIDs)
    end.

            %if
            %    rpc:rpc(CoordPID, request) == response -> bullyProcess(CoordPID, OtherPIDs)
            %    true -> 
%
            %receive
            %    election -> ;
            %    coordinator -> ;
%    .

%Aufgabenteil b)
%Beliebige Menge an Prozessen startbar, Liste aller Prozesse wird zurückgegeben
setup(Amount) -> setupIntern(Amount, []).

%Erstelle erst alle Prozesse, bevor ihre Logik selbst startet
%setupIntern(0, []) -> done.
setupIntern(0, ListPIDs) -> setupInternStartup(lists:max(ListPIDs), ListPIDs, ListPIDs);
setupIntern(Amount, ListPIDs) ->
    A = spawn(?MODULE, bullyProcess, [undefined, undefined]),
    setupIntern(Amount - 1, lists:append(ListPIDs, [A]).

%Starte die Logik aller Prozesse, indem ihnen der Initial-Koordinator und die anderen Prozesse bekannt gemacht werden.
%setupInternStartup(coordPID, allPIDs, []) -> darfNichtVorkommen.
setupInternStartup(_, AllPIDs, []) -> AllPIDs;
setupInternStartup(CoordPID, AllPIDs, [LastPID]) ->
    lastPID!{startup, CoordPID, lists:filter(fun(X) -> X /= LastPID end, AllPIDs)},
    setupInternStartup(CoordPID, AllPIDs, []);
setupInternStartup(CoordPID, AllPIDs, [FirstPID|OtherPIDs]) -> 
    lastPID!{startup, CoordPID, lists:filter(fun(X) -> X /= FirstPID end, AllPIDs)},
    setupInternStartup(CoordPID, AllPIDs, OtherPIDs).

