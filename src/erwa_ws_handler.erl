%%
%% Copyright (c) 2014-2015 Bas Wegh
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

%% @private
-module(erwa_ws_handler).
-behaviour(cowboy_websocket_handler).

-export([init/3]).
-export([websocket_init/3]).
-export([websocket_handle/3]).
-export([websocket_info/3]).
-export([websocket_terminate/3]).

-define(SUBPROTHEADER,<<"sec-websocket-protocol">>).
-define(WSMSGPACK,<<"wamp.2.msgpack">>).
-define(WSJSON,<<"wamp.2.json">>).
-define(WSMSGPACK_BATCHED,<<"wamp.2.msgpack.batched">>).
-define(WSJSON_BATCHED,<<"wamp.2.json.batched">>).

-record(state,{
  enc = undefined,
  ws_enc = undefined,
  router = undefined,
  buffer = <<"">>
               }).

init({Transport, http}, _Req, _Opts) when Transport == tcp; Transport == ssl ->
  {upgrade, protocol, cowboy_websocket}.

websocket_init(_TransportName, Req, _Opts) ->
  % need to check for the wamp.2.json or wamp.2.msgpack
  {ok, Protocols, Req1} = cowboy_req:parse_header(?SUBPROTHEADER, Req),
  case find_supported_protocol(Protocols) of
      {Enc,WsEncoding,Header} ->
        Req2  = cowboy_req:set_resp_header(?SUBPROTHEADER,Header,Req1),
        {ok,Req2,#state{enc=Enc,ws_enc=WsEncoding}};
      _ ->
        % unsupported
        {shutdown,Req1}
  end.


websocket_handle({WsEnc, Data}, Req, #state{ws_enc=WsEnc}=State) ->
  {ok,NewState} = handle_wamp(Data,State),
  {ok,Req,NewState};
websocket_handle(Data, Req, State) ->
  erlang:error(unsupported,[Data,Req,State]),
  {ok, Req, State}.

websocket_info({erwa,shutdown}, Req, State) ->
  {shutdown,Req,State};
websocket_info({erwa,Msg}, Req, #state{enc=Enc,ws_enc=WsEnc}=State) when is_tuple(Msg)->
	Reply = erwa_protocol:serialize(Msg,Enc),
	{reply,{WsEnc,Reply},Req,State};
websocket_info(_Data, Req, State) ->
  {ok,Req,State}.

websocket_terminate(_Reason, _Req, _State) ->
  ok.


handle_wamp(Data,#state{buffer=Buffer, enc=Enc, router=Router}=State) ->
  {Messages,NewBuffer} = erwa_protocol:deserialize(<<Buffer/binary, Data/binary>>,Enc),
  {ok,NewRouter} = erwa_router:forward_messages(Messages,Router),
  {ok,State#state{router=NewRouter,buffer=NewBuffer}}.


-spec find_supported_protocol([binary()]) -> atom() | {json|json_batched|msgpack|msgpack_batched,text|binary,binary()}.
find_supported_protocol([]) ->
  none;
find_supported_protocol([?WSJSON|_T]) ->
  {json,text,?WSJSON};
find_supported_protocol([?WSJSON_BATCHED|_T]) ->
  {json_batched,text,?WSJSON_BATCHED};
find_supported_protocol([?WSMSGPACK|_T]) ->
  {msgpack,binary,?WSMSGPACK};
find_supported_protocol([?WSMSGPACK_BATCHED|_T]) ->
  {msgpack_batched,binary,?WSMSGPACK_BATCHED};
find_supported_protocol([_|T]) ->
  find_supported_protocol(T).





-ifdef(TEST).

header_find_test() ->
  {json_batched,text,?WSJSON_BATCHED} = find_supported_protocol([?WSJSON_BATCHED,?WSJSON]).


-endif.
