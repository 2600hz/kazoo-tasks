%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2016-2025, 2600Hz
%%% @doc
%%% @author Dat Huynh
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(tasks_ra_action).

%% API
-export([process_command/1
        ,pipeline_command/1
        ,leader_query/0
        ,local_query/0
        ]).

-include("tasks.hrl").
-include_lib("kazoo_tasks/include/task_fields.hrl").
-include_lib("kazoo_stdlib/include/kazoo_json.hrl").

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec process_command(any()) -> any().
process_command(Cmd) ->
    case ra:process_command(tasks_ra_node:ra_name(), Cmd) of
        {'timeout', _} ->
            {'error', 'timeout'};
        {'error', _}=Error ->
            Error;
        {'ok', Reply, _ServerId} ->
            Reply
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec pipeline_command(any()) -> 'ok'.
pipeline_command(Cmd) ->
    ra:pipeline_command(tasks_ra_node:ra_name(), Cmd).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec leader_query() -> any().
leader_query() ->
    Fun = state_query(),
    try ra:leader_query(tasks_ra_node:ra_name(), Fun) of
        {'ok', {_, State}, _Id} -> State
    catch
        _:_ -> {'error', 'raft_nodes_unavailable'}
    end.

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec local_query() -> any().
local_query() ->
    Fun = state_query(),
    try ra:local_query(tasks_ra_node:ra_name(), Fun) of
        {'ok', {_, State}, _Id} -> State
    catch
        _:_ -> {'error', 'raft_nodes_unavailable'}
    end.

state_query() ->
    fun(State) ->
            State
    end.