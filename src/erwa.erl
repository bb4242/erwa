%%
%% Copyright (c) 2014 Bas Wegh
%%
%% Permission is hereby granted, free of charge, to any person obtaining a copy
%% of this software and associated documentation files (the "Software"), to deal
%% in the Software without restriction, including without limitation the rights
%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the Software is
%% furnished to do so, subject to the following conditions:
%%
%% The above copyright notice and this permission notice shall be included in all
%% copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
%% SOFTWARE.
%%

-module(erwa).

-export([start_realm/1]).
-export([stop_realm/1]).
-export([get_router_for_realm/1]).

-export([connect/3]).


-spec start_realm(Name :: binary() ) -> ok.
start_realm(Name) ->
  erwa_realms:add(Name).


-spec stop_realm(Name :: binary()) -> {ok,Info :: atom()} | {error, Reason :: atom()}.
stop_realm(Name) ->
  erwa_realms:remove(Name).

-spec get_router_for_realm(Realm :: binary() ) -> {ok, Pid :: pid()} | {error, not_found}.
get_router_for_realm(Realm) ->
  erwa_realms:get_router(Realm).




-spec connect(Realm :: binary(), Module :: atom(), Args :: any()) -> {ok,pid()}.
connect(Realm,Module,Args) ->
  supervisor:start_child(erwa_con_sup,[[{realm,Realm},{module,Module},{args,Args}]]).



-ifdef(TEST).




-endif.