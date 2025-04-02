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
-module(tasks_ra).
-behaviour(ra_machine).

-export([init/1
        ,apply/3
        ]).

-include("tasks.hrl").

-record(ra_state, {locks = #{} :: tasks_map()}).
-type state() :: #ra_state{}.
-type tasks_map() :: #{task_worker() => node()}.

-type command() :: {'acquire' | 'release', task_worker(), node()}.
-type reply() :: {'ok', node()} | {'error', 'already_locked'} | 'ok'.

-spec init(map()) -> state().
init(#{}) -> #ra_state{}.

-spec apply(ra_machine:command_meta_data(), command(), state()) -> {state(), reply()}.
apply(_Meta, {'acquire', TaskWorker, Node}, #ra_state{locks = Locks} = State) ->
    case maps:find(TaskWorker, Locks) of
        'error' ->
            NewLocks = maps:put(TaskWorker, Node, Locks),
            lager:info("acquiring ~s worker on node ~s", [TaskWorker, Node]),
            {State#ra_state{locks = NewLocks}, {'ok', Node}};
        {'ok', _ExistingNode} ->
            {State, {'error', 'already_locked'}}
    end;

apply(_Meta, {'release', TaskWorker, Node}, #ra_state{locks = Locks} = State) ->
    case maps:find(TaskWorker, Locks) of
        {'ok', Node} ->
            lager:info("release ~s worker on node ~s", [TaskWorker, Node]),
            NewLocks = maps:remove(TaskWorker, Locks),
            {State#ra_state{locks = NewLocks}, 'ok'};
        'error' ->
            {State, 'ok'}
    end;

apply(_Meta, Cmd, State) ->
    lager:debug("unknown command ~p for tasks ra state machine~n", [Cmd]),
    {State, 'unknown_command'}.
