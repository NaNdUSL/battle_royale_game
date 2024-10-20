-module(myserver).
-export([start/1]).

-define(Max_vel, 0.8).
-define(Gav, 0.03).

start(Port) -> spawn(fun() -> server(Port) end).

server(Port) ->
	{ok, LSock} = gen_tcp:listen(Port, [binary, {packet, line}, {reuseaddr, true}]),
	Logs = spawn(fun() -> login_manager(update_logs_from_file("logs")) end),
	register(queue_manager, spawn(fun() -> queue_manager(#{}, 0, null, 0) end)),
	spawn(fun() -> acceptor(LSock, Logs) end),

	receive stop -> ok end.

update_file_logs(Map) ->
	LM = maps:to_list(Map),
	Data = [lists:concat([User, ",", Pass, ",", Wins, "\n"]) || {User, {Pass, _, Wins}} <- LM],
	file:write_file("logs", binary:list_to_bin(Data)).

update_logs_from_file(FileName) ->
	 case file:read_file(FileName) of

		{ok, Data} ->
			file:read_file(FileName),
    		Temp = binary:split(Data, [<<"\n">>], [global]),
    		Aux = [{User, {Pass, false, string:to_integer(Wins)}} || [User, Pass, Wins] <- [string:split(binary:bin_to_list(T), ",", all) || T <- Temp, length(binary:bin_to_list(T)) > 0 ] ],
			Values = [{User, {Pass, Online, Wins}} || {User, {Pass, Online, {Wins, _}}} <- Aux ],
			maps:from_list(Values);

		{error, _} ->
			#{}
	end.

acceptor(LSock, Logs) ->
	Self = self(),
	{ok, Sock} = gen_tcp:accept(LSock),
	LB = spawn(fun() -> leader_board(Logs, Self) end),
	spawn(fun() -> acceptor(LSock, Logs) end),
	Logs ! {enter, self()},
	login_checker(Sock, Logs, LB).

leader_board(Logs, Self) ->
	receive
		stop -> ok
		after 1000 -> Logs ! {leaders, Self},
			leader_board(Logs, Self)
	end.

login_manager(Map) ->
	% io:format("~p~n", [Map]),
    receive
    	{enter, _From} ->
    		io:format("started login_manager~n", []),
    		login_manager(Map);

        {create_account, Username, Passwd, From} ->
    		io:format("created account~n", []),
			case maps:is_key(Username, Map) of
				true -> 
					From ! {user_exists, self()},
					login_manager(Map);
				false ->
					From ! {ok_created, self()},
					update_file_logs(maps:put(Username, {Passwd, false, 0}, Map)),
					login_manager(maps:put(Username, {Passwd, false, 0}, Map))
			end;

		{close_account, Username, Passwd, From} ->
    		io:format("closed account~n", []),
			case maps:find(Username, Map) of
				{ok, {Passwd, _, _}} ->
					From ! {ok_closed, self()},
					update_file_logs(maps:remove(Username, Map)),
					login_manager(maps:remove(Username, Map));
				_ ->
					From ! {invalid, self()},
					login_manager(Map)
			end;

		{login, Username, Passwd, From} ->
    		io:format("logged in~n", []),
			case maps:find(Username, Map) of
				{ok, {Passwd, _, Wins}} ->
					From ! {ok_loggedin, self()},
					login_manager(maps:update(Username, {Passwd, true, Wins}, Map));
				_ ->
					From ! {invalid, self()},
					login_manager(Map)
			end;

		{logout, Username, From} ->
    		io:format("logged out~n", []),
			case maps:find(Username, Map) of
				{ok, {Passwd, _, Wins}} -> 
					From ! {ok_loggedout, self()},
					login_manager(maps:update(Username, {Passwd, false, Wins}, Map));
				_ ->
					From ! {invalid, self()},
					login_manager(Map)
			end;

		{leaders, User} ->
    		% io:format("leaderboard~n", []),
			Lista = maps:to_list(Map),
			L = lists:sort([{Wins, Username} || {Username, {_, _, Wins}} <- Lista]),
			RM = lists:reverse(L),
			M = lists:concat([lists:concat(["{", Nome, ";", Wins, "},"]) || {Wins, Nome} <- RM]),
			User ! {leaderboard, "leaders," ++ M ++ "\n", self()},
			login_manager(Map);

		{winner, Username, _From} ->
    		io:format("winner~n", []),
			case maps:find(Username, Map) of
				{ok, {Passwd, Online, Wins}} ->
					io:format("adicionado uma vitoria~n",[]),
					update_file_logs(maps:update(Username, {Passwd, Online, Wins + 1}, Map)),
					login_manager(maps:update(Username, {Passwd, Online, Wins + 1}, Map));
				_ ->
					login_manager(Map)
			end
	end.

login_checker(Sock, Logs, LB) ->
	receive

		{leaderboard, M, _From} ->
			gen_tcp:send(Sock, M),
			login_checker(Sock, Logs, LB);

		{ok_created, _From} ->
			gen_tcp:send(Sock, "created\n"),
			login_checker(Sock, Logs, LB);

		{ok_closed, _From} ->
			gen_tcp:send(Sock, "closed\n"),
			login_checker(Sock, Logs, LB);

		{ok_loggedin, _From} ->
			gen_tcp:send(Sock, "in\n"),
			login_checker(Sock, Logs, LB);

		{ok_loggedout, _From} ->
			gen_tcp:send(Sock, "out\n"),
			login_checker(Sock, Logs, LB);

		{user_exists, _From} ->
			gen_tcp:send(Sock, "exists\n"),
			login_checker(Sock, Logs, LB);

		{tcp, _, Data} ->
			[Info | Rest] = string:tokens(binary:bin_to_list(Data), ",\r\n"),
			case Info of
				"create" ->
					% io:format("created~n",[]),
					Logs ! {create_account, lists:nth(1, Rest), lists:nth(2, Rest), self()};
				"login" ->
					% io:format("loggei~n",[]),
					Logs ! {login, lists:nth(1, Rest), lists:nth(2, Rest), self()};
				"logout" ->
					Logs ! {logout, lists:nth(1, Rest), self()};
				"close" ->
					Logs ! {close_account, lists:nth(1, Rest), lists:nth(2, Rest), self()};
				"leaders" ->
					Logs ! {leaders, self()};
				"play" ->
					% io:format("i'm in: ~p~n", [lists:nth(1, Rest)]),
					Is_alive = is_process_alive(LB),
					if
						Is_alive ->
							LB ! stop
					end,
					play(lists:nth(1, Rest), self()),
					client(Sock, Logs, null);
				_ ->
					login_checker(Sock, Logs, LB)
			end,
			login_checker(Sock, Logs, LB);

		{tcp_closed, _} ->
			io:format("closed ~n");

		{tcp_error, _, _} ->
			io:format("closed ~n")

	end.

play(Username, Client) ->
queue_manager ! {play, Username, Client}.

queue_manager(Jogadores, Timeout, Timer, Partidas) ->

	Self = self(),

	if
		Partidas < 4 ->
			Size = maps:size(Jogadores),
			if
				Size =:= 8 ->
					Is_alive = is_process_alive(Timer),
                    if
                        Is_alive ->
                            Timer ! stop
                    end,

                    Partida = spawn(fun() -> partida(Jogadores, gera_cristais(), math:sqrt((1024 * 1024) + (800 * 800))) end),
                    spawn(fun() -> ticker(Partida) end),
                    spawn(fun() -> crystal_spawner(Partida) end),
                    JT = maps:to_list(Jogadores),
                    [J ! {ready, Partida, self()} || {J, _} <- JT],
                    queue_manager(#{}, false, null, Partidas + 1);

                Size >= 3, Size < 8, Timeout ->
                    Partida = spawn(fun() -> partida(Jogadores, gera_cristais(), math:sqrt((1024 * 1024) + (800 * 800))) end),
                    spawn(fun() -> ticker(Partida) end),
                    spawn(fun() -> crystal_spawner(Partida) end),
                    JT = maps:to_list(Jogadores),
                    [J ! {ready, Partida, self()} || {J, _} <- JT],
                    queue_manager(#{}, false, null, Partidas + 1);

				true ->
					receive
						{play, Username, From} when Size =:= 0 ->
                            Timer1 = spawn(fun() -> timeout(10000, Self) end),
                        	X = [{255, 0, 0}, {0, 255, 0}, {0, 0, 255}],
                        	Jogadores_novo = maps:put(From, {Username, {0.0, 0.0}, lists:nth(rand:uniform(length(X)), X), 30.0, {rand:uniform(964) + 30, rand:uniform(740) + 30}, ?Max_vel}, Jogadores), 
                            queue_manager(Jogadores_novo, Timeout, Timer1, Partidas);

                        {play, Username, From} ->
                        	X = [{255, 0, 0}, {0, 255, 0}, {0, 0, 255}],
                        	Jogadores_novo = maps:put(From, {Username, {0.0, 0.0}, lists:nth(rand:uniform(length(X)), X), 30.0, {rand:uniform(964) + 30, rand:uniform(740) + 30}, ?Max_vel}, Jogadores), 
                            queue_manager(Jogadores_novo, Timeout, Timer, Partidas);
                        timeout ->
                            queue_manager(Jogadores, true, null, Partidas)
					end
			end;

		true ->
			receive
				{finnished, _From} ->
					queue_manager(Jogadores, false, null, Partidas - 1)
			end
	end.

timeout(N, To) ->

	receive
		stop -> stopped
		after N -> To ! timeout
	end.

client(Sock, Logs, Partida) ->

	receive
		{you_win, Username, _From} ->
			flush(),
			timer:sleep(5),
			gen_tcp:send(Sock, "changed\n"),
			Self = self(),
			LB = spawn(fun() -> leader_board(Logs, Self) end),
			io:format("ganhou~n",[]),
			Logs ! {winner, Username, self()},
			login_checker(Sock, Logs, LB);

		{out_lobby, _From} ->
			flush(),
			timer:sleep(5),
			gen_tcp:send(Sock, "changed\n"),
			Self = self(),
			LB = spawn(fun() -> leader_board(Logs, Self) end),
			io:format("perdeu~n",[]),
			login_checker(Sock, Logs, LB)

		after 0 ->

			receive
				{message, Zona, Message, _From} ->
					gen_tcp:send(Sock, "update," ++ lists:concat([Zona, ",", Message]) ++ "\n"),
					client(Sock, Logs, Partida);

				{ready, New, _From} ->
					gen_tcp:send(Sock, "ready\n"),
					io:format("ready~n", []),
					client(Sock, Logs, New);

				{tcp, _, Data} ->
					[Info | Rest] = string:tokens(binary:bin_to_list(Data), ",\r\n"),
					case Info of
						"update" ->
							
							{X, _} = string:to_float(lists:nth(1, Rest)),
							{Y, _} = string:to_float(lists:nth(2, Rest)),
							Boost = lists:nth(3, Rest),

							Partida ! {update_state, X, Y, Boost, self()},
							client(Sock, Logs, Partida);

						_ ->
							client(Sock, Logs, Partida)
					end;

				{tcp_closed, _} ->
					io:format("closed client~n");

				{tcp_error, _, _} ->
					io:format("closed client~n")

				after 0 -> client(Sock, Logs, Partida)
			end
	end.

flush() ->
	receive
		_ ->
			flush()
		after 0 ->
			true
	end.


partida(Jogadores, Cristais, Zona) ->

	receive

		{update_state, X, Y, Boost, From} ->

			{Username, _Mouse, Color, Mass, Pos, Vel} = maps:get(From, Jogadores),

			if
				Boost =:= "boost", Vel * 8 =< ?Max_vel * 8, Mass - 10 >= 30 ->
					Novos_jogadores = maps:update(From, {Username, {X, Y}, Color, Mass - 10, Pos, Vel * 8}, Jogadores);
				true ->
					Novos_jogadores = maps:update(From, {Username, {X, Y}, Color, Mass, Pos, Vel}, Jogadores)
			end,
			partida(Novos_jogadores, Cristais, Zona);

		{spawn_cristais, _From} ->

			SizeC = maps:size(Cristais),
			if
				SizeC < 10 ->
					X = lists:seq(1, 10 - SizeC),
					NCrist = lists:nth(rand:uniform(length(X)), X),
					NOVO_C = add_crist(NCrist, Cristais, 1),
					partida(Jogadores, NOVO_C, Zona);

				true ->
					partida(Jogadores, Cristais, Zona)
			end;

		{ticked, _From} ->

			FinalPlayer = maps:to_list(Jogadores),
			FinalCristal = maps:to_list(Cristais),

			[parse_players(FinalPlayer, 0, Cristais, J, "", [], Zona) || {J, _} <- FinalPlayer],
			
			New_LP = update_game(FinalPlayer, FinalPlayer),

			{Reduced_players, NZona} = verifica_zona(New_LP, New_LP, Zona),

			{LP, LC} = update_mortesC([], Reduced_players, FinalCristal),

			NNew_LP = update_mortesP(LP, LP, LP),

			NLC = maps:from_list(LC),
			NLP = maps:from_list(NNew_LP),
			verifica_final_partida(NLP, NLC, NZona)
	end.

verifica_final_partida(NLP, NLC, NZona) ->
	Size = maps:size(NLP),
	if
		Size > 1 ->
			partida(NLP, NLC, NZona - 0.01);

		Size =:= 1 ->
			[{Player, {Username, _Mouse, _ColorP, _MassP, _Pos, _VelP}} | _] = maps:to_list(NLP),
			Player ! {you_win, Username, self()},
			queue_manager ! {finnished, self()};

		true ->
			ok
	end.

verifica_zona(Players, [], Zona) ->
	{Players, Zona};

verifica_zona(Players, [{Player, {Username, Mouse, ColorP, MassP, {PosX, PosY}, VelP}} | Jogadores], Zona) ->

	DXY = math:sqrt(math:pow(PosX - 512, 2) + math:pow(PosY - 400, 2)),
	% io:format("~p......~p~n", [DXY, Zona / 2]),

	if
		MassP < 30.0 ->
			NovoJ = lists:keydelete(Player, 1, Players),
			Player ! {out_lobby, self()},
			% io:format("antes......~p~n", [Players]),
			% io:format("depois......~p~n", [NovoJ]),
			verifica_zona(NovoJ, Jogadores, Zona);

		true ->
			if
				Zona / 2 >= 0 ->
					if
						DXY >= Zona / 2 ->
							NovoJ = lists:keyreplace(Player, 1, Players, {Player, {Username, Mouse, ColorP, MassP - 0.01, {PosX, PosY}, VelP}});
						true ->
							NovoJ = lists:keyreplace(Player, 1, Players, {Player, {Username, Mouse, ColorP, MassP, {PosX, PosY}, VelP}})
					end,
					verifica_zona(NovoJ, Jogadores, Zona);
				true ->
					NovoJ = lists:keyreplace(Player, 1, Players, {Player, {Username, Mouse, ColorP, MassP, {PosX, PosY}, VelP}}),
					verifica_zona(NovoJ, Jogadores, 0)
			end
	end.

add_crist(0, Cristais, _) ->
	Cristais;

add_crist(NCrist, Cristais, I) ->

	Value = maps:is_key(I, Cristais),
	if
		Value ->
			add_crist(NCrist, Cristais, I + 1);

		true ->
			X = [{255, 0, 0}, {0, 255, 0}, {0, 0, 255}],
			NewC = {{rand:uniform(984) + 20, rand:uniform(760) + 20}, lists:nth(rand:uniform(length(X)), X), 20.0},
			add_crist(NCrist - 1, maps:put(I, NewC, Cristais), I + 1)
	end.

ticker(Partida) ->
	receive

		after 1 -> Partida ! {ticked, self()},
			ticker(Partida)
	end.

crystal_spawner(Partida) ->
	receive

		after 10000 -> Partida ! {spawn_cristais, self()},
			crystal_spawner(Partida)
	end.

update_mortesC(NP, [], Cristais) ->
	{NP, Cristais};

update_mortesC(NP, [J | Jogadores], Cristais) ->

	{NJ, NCristais} = remove_cristal(Cristais, J, Cristais),
	update_mortesC([NJ | NP], Jogadores, NCristais).

remove_cristal(Cristais, J, []) ->
	{J, Cristais};

remove_cristal(Cristais, {Player, {Username, Mouse, ColorP, MassP, PosP, VelP}}, [{I, {PosC, ColorC, MassC}} | Resto]) ->
	{PosXP, PosYP} = PosP, 
	{PosXC, PosYC} = PosC,
	% {RedC, GreenC, BlueC} = ColorC,
	DistPC = math:sqrt(math:pow(PosXP - PosXC, 2) + math:pow(PosYP - PosYC, 2)),
	if 
		DistPC =< MassP/2 + MassC/2 ->
			if
				MassP + 10 =< 70 ->
					NP = {Player, {Username, Mouse, ColorC, MassP + 10, PosP, VelP - VelP * 0.05}},
					NC = lists:keydelete(I, 1, Cristais);
				true->
					NP = {Player, {Username, Mouse, ColorC, MassP, PosP, VelP}},
					NC = lists:keydelete(I, 1, Cristais)
			end;
		true ->
			NP = {Player, {Username, Mouse, ColorP, MassP, PosP, VelP}},
			NC = Cristais
	end,
	remove_cristal(NC, NP, Resto).


update_mortesP(NP, [], _) ->
	NP;

update_mortesP(NP, [J | Resto], [_ | Jogadores]) ->
	Players = verify(NP, J, Jogadores),
	update_mortesP(Players, Resto, Jogadores).

verify(J, _, []) ->
	J;

verify(NP, {Player1, {Username1, Mouse1, ColorP1, MassP1, PosP1, VelP1}}, [{Player2, {Username2, Mouse2, ColorP2, MassP2, PosP2, VelP2}} | Resto]) ->

	{PosXP1, PosYP1} = PosP1,
	{PosXP2, PosYP2} = PosP2,
	DistP1P2 = math:sqrt(math:pow(PosXP1 - PosXP2, 2) + math:pow(PosYP1 - PosYP2, 2)),
	% 	New_VelP1 = VelP1 - VelP1*0.2,
	if
		DistP1P2 =< MassP1/2 + MassP2/2 ->
			Res = color_win(ColorP1, ColorP2),

			New_VelP1 = -VelP1,
			New_VelP2 = -VelP2,

			% {DirX, DirY} = calculate_dirs(PosXP1, PosYP1, PosXP2, PosYP2),

			if 
				Res =:= player1 ->
					New_MassP1 =  MassP1 + 5,
					New_MassP2 =  MassP2 - 5;

				Res =:= player2 ->
					New_MassP1 =  MassP1 - 5,
					New_MassP2 =  MassP2 + 5;

				true ->
					if
						MassP1 > MassP2 ->
							New_MassP1 =  MassP1 + 5,
							New_MassP2 =  MassP2 - 5;

						MassP1 < MassP2 ->
							New_MassP1 =  MassP1 - 5,
							New_MassP2 =  MassP2 + 5;

						true ->

							New_MassP1 =  MassP1 - 5,
							New_MassP2 =  MassP2 - 5
					end
			end,

			% New_PosP1 = {PosXP1 + (0.1 * DirX), PosYP1 + (0.1 * DirY)},

			if
				New_MassP1 < 30.0, New_MassP2 < 30.0 ->
				 	JogadoresN1 = lists:keydelete(Player1, 1, NP),
				 	JogadoresN2 = lists:keydelete(Player2, 1, JogadoresN1),
				 	Player1 ! {out_lobby, self()},
				 	Player2 ! {out_lobby, self()};

				New_MassP1 < 30.0 ->
					% New_PosP1 = {PosXP1 + (0.01 * DirX), PosYP1 + (0.01 * DirY)},
				 	JogadoresN1 = lists:keydelete(Player1, 1, NP),
					JogadoresN2 = lists:keyreplace(Player2, 1, JogadoresN1, {Player2, {Username2, Mouse2, ColorP2, New_MassP2, PosP2, New_VelP2}}),
				 	Player1 ! {out_lobby, self()};

				New_MassP2 < 30.0 ->
					% New_PosP1 = {PosXP1 + (0.01 * DirX), PosYP1 + (0.01 * DirY)},
					JogadoresN1 = lists:keyreplace(Player1, 1, NP, {Player1, {Username1, Mouse1, ColorP1, New_MassP1, PosP1, New_VelP1}}),
				 	JogadoresN2 = lists:keydelete(Player2, 1, JogadoresN1),
				 	Player2 ! {out_lobby, self()};

				true ->
					% New_PosP1 = {PosXP1 + (0.01 * DirX), PosYP1 + (0.01 * DirY)},
					JogadoresN1 = lists:keyreplace(Player1, 1, NP, {Player1, {Username1, Mouse1, ColorP1, New_MassP1, PosP1, New_VelP1}}),
					JogadoresN2 = lists:keyreplace(Player2, 1, JogadoresN1, {Player2, {Username2, Mouse2, ColorP2, New_MassP2, PosP2, New_VelP2}})
			end;

		true ->
			% New_PosP1 = PosP1,
			New_VelP1 = VelP1,
			JogadoresN2 = NP

	end,
	verify(JogadoresN2, {Player1, {Username1, Mouse1, ColorP1, MassP1, PosP1, New_VelP1}}, Resto).

color_win(ColorP1, ColorP2) -> 
	
	if
		ColorP1 =:= {255, 0, 0}, ColorP2 =:= {0, 255, 0} ->
			player1;

		ColorP1 =:= {255, 0, 0}, ColorP2 =:= {0, 0, 255} ->
			player2;	

		ColorP1 =:= {0, 255, 0}, ColorP2 =:= {255, 0, 0} ->
			player2;	

		ColorP1 =:= {0, 255, 0}, ColorP2 =:= {0, 0, 255} ->	
			player1;

		ColorP1 =:= {0, 0, 255}, ColorP2 =:= {0, 255, 0} ->	
			player2;

		ColorP1 =:= {0, 0, 255}, ColorP2 =:= {255, 0, 0} ->	
			player1;

		true ->
			tie
	end.	

update_game(Updated, []) ->
	Updated;

update_game(Updated, [{Player, {Username, Mouse, Color, Mass, Pos, Vel}} | Jogadores]) ->
	{SX, SY, NV} = calculate_pos(Mass, Color, Pos, Mouse, math:pow(1, -3), Vel),
	NL = lists:keyreplace(Player, 1, Updated, {Player, {Username, Mouse, Color, Mass, {SX, SY}, NV}}),
	update_game(NL, Jogadores).

calculate_pos(Mass, _Color, {Pos_X, Pos_Y}, {MouseX, MouseY}, Time, Vel) ->

	{VX, VY, NV} = calculate_vel({Pos_X, Pos_Y}, {MouseX, MouseY}, Time, Vel),
	if 

		Pos_X + VX - Mass/2 > 0, Pos_X + VX + Mass/2 < 1024 ->
			Pos_Xfinal = Pos_X + VX;
		true ->
			Pos_Xfinal = Pos_X
	end,
	if 
		Pos_Y + VY - Mass/2 > 0, Pos_Y + VY + Mass/2 < 800 ->
			Pos_Yfinal = Pos_Y + VY;
		true -> 
			Pos_Yfinal = Pos_Y
	end,
	{Pos_Xfinal, Pos_Yfinal, NV}.

calculate_vel({Pos_X, Pos_Y}, {MouseX, MouseY}, _Time, Vel) ->

	{DirX, DirY} = calculate_dirs(Pos_X, Pos_Y, MouseX, MouseY),
	if
		Vel < 0 ->
    		DX = math:sqrt(math:pow(MouseX - Pos_X, 2)) * (Vel / math:sqrt(math:pow(Vel, 2))),
    		DY = math:sqrt(math:pow(MouseY - Pos_Y, 2)) * (Vel / math:sqrt(math:pow(Vel, 2))),

			New_DX = DirX * 0.001 * (DX + ?Gav),
			New_DY = DirY * 0.001 * (DY + ?Gav),
			NewVel = Vel + ?Gav,
			{New_DX, New_DY, NewVel};

		Vel >= 0, Vel =< 1 ->
			DX = math:sqrt(math:pow(MouseX - Pos_X, 2)),
    		DY = math:sqrt(math:pow(MouseY - Pos_Y, 2)),
			NewVel = ?Max_vel,
			New_DX = DirX * 0.001 * DX,
			New_DY = DirY * 0.001 * DY,
			{min(New_DX, NewVel), min(New_DY, NewVel), NewVel};

		Vel > 1,  Vel < ?Max_vel ->

			DX = math:sqrt(math:pow(MouseX - Pos_X, 2)) * (Vel / math:sqrt(math:pow(Vel, 2))),
    		DY = math:sqrt(math:pow(MouseY - Pos_Y, 2)) * (Vel / math:sqrt(math:pow(Vel, 2))),
			NewVel = Vel,
			New_DX = DirX * 0.001 * DX,
			New_DY = DirY * 0.001 * DY,
			{min(New_DX, NewVel), min(New_DY, NewVel), NewVel};

		true ->

			DX = math:sqrt(math:pow(MouseX - Pos_X, 2)) * (Vel / math:sqrt(math:pow(Vel, 2))),
    		DY = math:sqrt(math:pow(MouseY - Pos_Y, 2)) * (Vel / math:sqrt(math:pow(Vel, 2))),

			New_DX = DirX * 0.005 * (DX - ?Gav),
			New_DY = DirY * 0.005 * (DY - ?Gav),
			NewVel = Vel - ?Gav,
			{New_DX, New_DY, NewVel}

	end.
	

calculate_dirs(Pos_X, Pos_Y, MouseX, MouseY) ->
	normalize(MouseX - Pos_X, MouseY - Pos_Y).

normalize(VecX, VecY) ->
	if
		VecX =/= 0.0 ->
			NormX = VecX * (1 / math:sqrt(math:pow(VecX, 2)));

		true -> 
			NormX = 0.0
	end,

	if
		VecY =/= 0.0 ->
			NormY = VecY * (1 / math:sqrt(math:pow(VecY, 2)));

		true -> 
			NormY = 0.0
	end,
	{NormX, NormY}.

gera_cristais() ->
	X = [{255, 0, 0}, {0, 255, 0}, {0, 0, 255}],
	Cristais = [{I, {{rand:uniform(984) + 20, rand:uniform(760) + 20}, lists:nth(rand:uniform(length(X)), X), 20.0}} || I <- lists:seq(1, 10)],
	maps:from_list(Cristais).

parse_players(Jogadores, Curr, Cristais, From, Mens_jogs, Mens_cris, Zona) ->
	Map_size = maps:size(Cristais),
	% io:format("Size map: ~p~n", [Jogadores]),
	if
		length(Jogadores) =/= 0 ->
			[{_Jogador, {Username, _, {R, G, B}, Mass, {X, Y}, _Vel}} | Resto] = Jogadores,
			% Jogador ! {info, self()},
			parse_players(Resto, Curr + 1, Cristais, From, lists:concat(["{\"player", "\":{\"username\":", "\"", Username, "\",", "\"pos\":[", X, ",", Y, "], \"color\":[", R, ",", G, ",", B, "],", "\"mass\":", Mass, "}},", Mens_jogs]), Mens_cris, Zona);

		Map_size =/= 0 ->
			I = maps:iterator(Cristais),
			{K1, {{XC, YC}, {RC, GC, BC}, MassC}, _} = maps:next(I),
			Aux = lists:concat([[lists:concat(["{\"crystal\":{\"pos\":[", XC, ",", YC, "],\"color\":[", RC, ",", GC, ",", BC, "],", "\"mass\":", MassC, "}}"])], Mens_cris]),
			% io:format("Size map: ~p~n", [Aux]),
			parse_players(Jogadores, Curr, maps:remove(K1, Cristais), From, Mens_jogs, Aux, Zona);

		true ->
			New_jogs = string:substr(Mens_jogs, 1, length(Mens_jogs) - 1),
			New_cris = string:join(Mens_cris, ","),
			% io:format("message: ~p~n", ["{\"players\":[" ++ New_jogs ++ "],\"crystals\":[" ++ New_cris ++ "]}"]),
			From ! {message, Zona, "{\"players\":[" ++ New_jogs ++ "],\"crystals\":[" ++ New_cris ++ "]}", self()}
	end.