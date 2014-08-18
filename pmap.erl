
pmap_n(_,_,[]) -> [];

pmap_n(N,F,L) when N > length(L)  ->
pmap(F,L);

pmap_n(N,F,L) when N =< length(L)  ->
  {FirstN,Rest} = lists:split(N,L),
  [pmap(F,FirstN)|pmap_n(N,F,Rest)].

pmap(F, L) ->
  S = self(),
  %% make_ref() returns a unique reference 
  %% we'll match on this later 
  Ref = erlang:make_ref(),
  Pids = lists:map(fun(I) ->
  spawn(fun() -> do_f(S, Ref, F, I) end)
        end, L),
        %% gather the results 
  gather(Pids, Ref).

do_f(Parent, Ref, F, I) ->
  Parent ! {self(), Ref, (catch F(I))}.

gather([Pid|T], Ref) ->
  receive
    {Pid, Ref, Ret} -> [Ret|gather(T, Ref)]
  end;
gather([], _) ->
   [].
    
