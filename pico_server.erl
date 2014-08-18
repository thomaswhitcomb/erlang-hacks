-module(pico_server).
-compile(export_all).

 
start(Port) ->
  start(Port,?MODULE).

start(Port,Module) ->
  {ok, ListenSocket} = gen_tcp:listen(Port, [binary, {packet, 0}, {active, false}]),
  spawn_link(fun() -> accept_request(ListenSocket,Module) end).

request(_Method,_Path,_QueryString,_Dict) ->
  {"text/html","<html><body><h1>Missing Callback module</h1></body></html>"}.

accept_request(ListenSocket,Module) ->
  case gen_tcp:accept(ListenSocket) of
    {ok, Socket} ->
      spawn(fun() ->
        handle_connection(Socket,Module)
      end),
      accept_request(ListenSocket,Module);
    {error, Reason} ->
      io:format("Accept Error: ~p~n", [Reason])
  end.
 
handle_connection(Socket,Module) ->
  try serve_request(Socket,Module) of
      _ -> ok
  catch
    _:Reason ->
      return_response(Socket,500,"Internal Server Error","text/plain",io_lib:format("Ouch: ~p",[Reason]))
  end,
  ok = gen_tcp:close(Socket).
 
serve_request(Socket,Module) ->
  {ok, Binary} = gen_tcp:recv(Socket, 0),
  [R|_Headers] = re:split( Binary, "\r\n" ),
  [Method,PathAndQuery,_Protocol] = re:split(R, " ",[{return,list}] ),
  {Path,QueryString} = httpd_util:split_path(PathAndQuery), 
  Dict = query_string_to_dict(QueryString),
  {Code,Msg,Type,Content} = 
    try Module:request(Method,Path,QueryString,Dict) of
      {ReturnType,ReturnContent} -> {200,"OK",ReturnType,ReturnContent}
    catch
      _:Reason -> {500,"Internal Server Error","text/plain",io_lib:format("Missing server module or thrown exception: ~p",[Reason])}
    end,
    return_response(Socket,Code,Msg,Type,Content). 

return_response(Socket,Code,Msg,Type,Response) ->
  {WD, JJ, MD, AA, HH, MN, SS} = get_local_time(),
  gen_tcp:send(Socket, io_lib:format("HTTP/1.1 ~p ~p~nDate: ~s, ~p ~s ~p ~p:~p:~p GMT~nServer: SigServ/1.0.0~nContent-type: ~s~n~n~s", [Code,Msg,WD, JJ, MD, AA, HH, MN, SS,Type,Response])).

query_string_to_dict([$?|Query]) ->
  Pairs = string:tokens(Query,"&"),
  Fn = fun(Item,Dict) ->
    I = string:chr(Item,$=),
    Key = string:substr(Item,1,I-1),
    Value = string:substr(Item,I+1),
    dict:store(httpd_util:decode_hex(Key),httpd_util:decode_hex(Value),Dict)
  end,
  lists:foldl(Fn,dict:new(),Pairs);

query_string_to_dict(PathInfo) ->
  io:format("PathInfo: ~p~n",[PathInfo]),
  dict:new().

%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
day(1) -> "Mon";
day(2) -> "Tue";
day(3) -> "Wed";
day(4) -> "Thu";
day(5) -> "Fri";
day(6) -> "Sat";
day(7) -> "Sun".
 
month(1) -> "Jan";
month(2) -> "Feb";
month(3) -> "Mar";
month(4) -> "Apr";
month(5) -> "May";
month(6) -> "Jun";
month(7) -> "Jul";
month(8) -> "Aug";
month(9) -> "Sep";
month(10) -> "Oct";
month(11) -> "Nov";
month(12) -> "Dec".
 
get_local_time() ->
  D = calendar:local_time(),
  [{{AA,MM,JJ},{HH,MN,SS}}] = calendar:local_time_to_universal_time_dst(D),
  WD = day(calendar:day_of_the_week(AA, MM, JJ)),
  MD = month(MM),
  {WD, JJ, MD, AA, HH, MN, SS}.
