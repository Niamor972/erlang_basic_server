-module(basic_server).
-export([start/0]).


start() ->
  spawn(fun () ->
    {ok, Sock} = gen_tcp:listen(4000, [{packet, line}]),
    ets:new(client_table, [set,public,named_table]),
    ets:new(msg_table, [ordered_set,public,named_table]),
    echo_loop(Sock)
    end).


echo_loop(Sock) ->
  {ok, Conn} = gen_tcp:accept(Sock),
  io:format("Got connection ~p: ~p~n", [ok, Conn]),
  ets:insert(client_table, {Conn, Conn}),
  Handler = spawn(fun () -> handle(Conn) end),
  gen_tcp:controlling_process(Conn, Handler),
  echo_loop(Sock).


handle(Conn) ->
  gen_tcp:send(Conn, "Nickname ?\n"),
  receive
    {tcp, Conn, Data} ->
      Nickname = re:replace(Data, "\\s+", "", [global,{return,list}]),
      send_all(Nickname ++ " connected\n", Conn),
      %% send_everything(Conn),
      handle(Conn, Nickname);
    {tcp_closed, Conn} ->
      io:format("Connection closed: ~p~n", [Conn])
  end.

handle(Conn, ID) ->
  receive
    {tcp, Conn, Data} ->
      Message = ID ++ " says " ++ Data,
      ets:insert(msg_table, {Conn, Message}),
      send_all(Message, Conn),
      handle(Conn, ID);
    {tcp_closed, Conn} ->
      send_all(ID ++ " disconnected\n", Conn),
      io:format("Connection closed: ~p~n", [Conn])
  end.


send_all(Message, Sender) ->
  send_all(Message, Sender, ets:first(client_table)).

send_all(_,_, '$end_of_table') ->
  ok;

send_all(Message, Sender, Sender) ->
  send_all(Message, Sender, ets:next(client_table, Sender)),
  ok;

send_all(Message, Sender, Client) ->
  gen_tcp:send(Client, Message),
  send_all(Message, Sender, ets:next(client_table, Client)).


send_everything(Conn) ->
  send_everything(Conn, ets:first(msg_table)).

send_everything(_, '$end_of_table') ->
  ok;

send_everything(Conn, Message) ->
  io:format("Try to send [~p] to ~p~n", [Message, Conn]),
  gen_tcp:send(Conn, ets:lookup(msg_table, Message)),
  send_everything(Conn, ets:next(msg_table, Message)).
