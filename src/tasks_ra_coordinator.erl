%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2016-2024, 2600Hz
%%% @doc All gen_server tasks in node cluster will call acquire_task_lock/release_task_lock
%%% to take task leadership and execute
%%% @author Dat Huynh
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(tasks_ra_coordinator).
-behaviour(gen_server).

%% API
-export([start_link/0
        ,acquire_task_lock/1
        ,release_task_lock/1
        ]).

%% gen_server callbacks
-export([init/1
        ,handle_call/3
        ,handle_cast/2
        ,handle_info/2
        ,terminate/2
        ,code_change/3
        ]).

-include("tasks.hrl").

-define(SERVER, ?MODULE).

-record(state, {cluster_name :: atom()
               ,server_id :: ra:server_id()
               }).

-type state() :: #state{}.
%%%=============================================================================
%%% API
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Starts the server
%% @end
%%------------------------------------------------------------------------------
-spec start_link() -> gen_server:start_ret().
start_link() ->
    gen_server:start_link({'local', ?MODULE}, ?MODULE, [], []).

-spec acquire_task_lock(task_worker()) -> 'ok' | 'already_locked' | 'timeout'.
acquire_task_lock(TaskWorker) ->
    gen_server:call(?SERVER, {'acquire_lock', TaskWorker}).

-spec release_task_lock(task_worker()) -> 'ok'.
release_task_lock(TaskWorker) ->
    gen_server:cast(?SERVER, {'release_lock', TaskWorker}).

%%%=============================================================================
%%% gen_server callbacks
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Initializes the server.
%% @end
%%------------------------------------------------------------------------------
-spec init([]) -> {'ok', state()}.
init([]) ->
    {ok, #state{}}.

-spec handle_call(any(), kz_term:pid_ref(), state()) -> kz_types:handle_call_ret_state(state()).
handle_call({'acquire_lock', TaskWorker}, _From, State) ->
    Command = {'acquire', TaskWorker, node()},
    case tasks_ra_action:process_command(Command) of
        {'ok', Node} ->
            {'reply', {'ok', Node}, State};
        {'error', Reason} ->
            {'reply', Reason, State}
    end.

%%------------------------------------------------------------------------------
%% @doc Handling cast messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_cast(any(), state()) -> kz_types:handle_cast_ret_state(state()).
handle_cast({'release_lock', TaskWorker}, State) ->
    Command = {'release', TaskWorker, node()},
    _ = tasks_ra_action:process_command(Command),
    {'noreply', State}.

%%------------------------------------------------------------------------------
%% @doc Handling all non call/cast messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_info(any(), state()) -> kz_types:handle_info_ret_state(state()).
handle_info(_Info, State) ->
    lager:debug("unhandled message ~p", [_Info]),
    {'noreply', State}.

%%------------------------------------------------------------------------------
%% @doc This function is called by a `gen_server' when it is about to
%% terminate. It should be the opposite of `Module:init/1' and do any
%% necessary cleaning up. When it returns, the `gen_server' terminates
%% with Reason. The return value is ignored.
%% @end
%%------------------------------------------------------------------------------
-spec terminate(any(), state()) -> 'ok'.
terminate(_Reason, _State) ->
    lager:debug("~s terminating: ~p", [?MODULE, _Reason]).

%%------------------------------------------------------------------------------
%% @doc Convert process state when code is changed.
%% @end
%%------------------------------------------------------------------------------
-spec code_change(any(), state(), any()) -> {'ok', state()}.
code_change(_OldVsn, State, _Extra) ->
    {'ok', State}.
