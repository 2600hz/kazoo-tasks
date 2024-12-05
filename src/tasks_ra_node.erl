%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2016-2024, 2600Hz
%%% @doc
%%% @author Dat Huynh
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(tasks_ra_node).

-export([start/1, stop/1]).

-export([members/1
        ,id/1
        ,app_nodes/0
        ,make_ra_conf/2
        ,maybe_join/1
        ,join/1
        ,leave_and_force_delete_server/1
        ,restart/1
        ,start_new/1
        ,delete/1
        ,ra_name/0, ra_name/1
        ,available_nodes/1
        ]).

-include("tasks.hrl").
-type cluster() :: atom().

-define(TASKS_RA_MACHINE, 'tasks_ra').
-define(TICK_INTERVAL_MS, 20 * ?MILLISECONDS_IN_SECOND).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec ra_name() -> 'tasks'.
ra_name() -> 'tasks'.

-spec ra_name(Cluster) -> Cluster when Cluster :: cluster().
ra_name(Cluster) -> Cluster.

-spec id(Cluster) -> {Cluster, node()} when Cluster :: cluster().
id(Cluster) -> {ra_name(Cluster), node()}.

-spec members(Cluster) -> [{Cluster, node()}] when Cluster :: cluster().
members(Cluster) ->
    [{ra_name(Cluster), N} || N <- [node() | app_nodes()]].

ra_machine() ->
    {'module', ?TASKS_RA_MACHINE, ra_machine_config()}.

ra_machine_config() -> #{}.

-spec make_ra_conf(ra:server_id(), cluster()) -> ra_server:config().
make_ra_conf(ServerId, Cluster) ->
    Members = members(Cluster),
    UId = ra:new_uid(ra_lib:to_binary(Cluster)),
    #{cluster_name => Cluster
     ,id => ServerId
     ,uid => UId
     ,initial_members => Members
     ,log_init_args => #{uid => UId}
     ,tick_timeout => ?TICK_INTERVAL_MS
     ,machine => ra_machine()
     }.

-spec app_nodes() -> [node()].
app_nodes() ->
    Nodes = nodes(),
    {Replies, Bad} = rpc:multicall(Nodes, 'kapps_controller', 'list_apps', []),
    [Node || {Node, Res} <- lists:zip(Nodes -- Bad, Replies), is_app_node(Node, Res)].

-spec is_app_node(node(), kz_term:atoms() | {'badrpc', any()}) -> boolean().
is_app_node(_, Apps) when is_list(Apps) ->
    lists:member(?APP, Apps);
is_app_node(Node, {'badrpc', Reason}) ->
    lager:info("bad return from ~s checking app_nodes: ~p", [Node, Reason]),
    'false'.

-spec restart(cluster()) -> boolean().
restart(Cluster) ->
    Name = id(Cluster),
    case ra:restart_server(Name) of
        'ok' -> 'true';
        {'error', {'already_started', _}} -> 'true';
        {'error', 'name_not_registered'} -> 'false'
    end.

-spec start(cluster()) -> 'ok'.
start(Cluster) ->
    %% ensure_default_ra_system_started(),
    lager:info("starting ra cluster ~s", [Cluster]),
    case restart(Cluster) of
        'false' -> maybe_join(Cluster);
        'true' -> 'ok'
    end.

%%-spec ensure_default_ra_system_started() -> 'ok'.
%%ensure_default_ra_system_started() ->
%%    case ra_system:start_default() of
%%        {'ok', _Pid} -> 'ok';
%%        {'error', {'already_started', _Pid}} -> 'ok'
%%    end.

-spec maybe_join(cluster()) -> 'ok'.
maybe_join(Cluster) ->
    case app_nodes() of
        [] -> start_new(Cluster);
        _ -> join(Cluster)
    end.

-spec join(cluster()) -> 'ok'.
join(Cluster) ->
    ServerId = id(Cluster),
    Members = members(Cluster),
    RaConf = make_ra_conf(ServerId, Cluster),
    lager:info("ra joining cluster ~p", [RaConf]),
    'true' = join_add_member(Members, ServerId),
    'ok' = ra:start_server(RaConf).

-spec join_add_member([ra:server_id()], ra:server_id()) -> boolean().
join_add_member(Members, ServerId) ->
    case ra:add_member(Members -- [ServerId], ServerId) of
        {'ok', _, _Leader} -> 'true';
        {'error', {'no_more_servers_to_try', Es}} ->
            lists:all(fun(E) -> E =:= {'error', 'already_member'} end, Es)
    end.

-spec delete(cluster()) -> {'ok', ra:server_id()} | {'error', any()}.
delete(Cluster) ->
    {'ok', Members, _Leader} = ra:members(id(Cluster)),
    ra:delete_cluster(Members).

-spec leave_and_force_delete_server(cluster()) -> 'ok' | 'timeout' | {'error', 'noproc'}.
leave_and_force_delete_server(Cluster) ->
    lager:info("leaving cluster ~s", [Cluster]),
    ServerId = id(Cluster),
    {'ok', _Members, Leader} = ra:members(ServerId),
    %% TODO: double check
    ra:leave_and_delete_server(Leader, ServerId).

-spec start_new(cluster()) -> 'ok'.
start_new(Cluster) ->
    Members = members(Cluster),
    RaConfs = [make_ra_conf(ServerId, Cluster) || ServerId <- Members],
    lager:info("ra starting new cluster ~p", [RaConfs]),
    {'ok', Members, []} = ra:start_cluster(RaConfs),
    'ok'.

-spec stop(cluster()) -> 'ok'.
stop(Cluster) ->
    %% TODO: https://github.com/rabbitmq/ra/pull/340 fixes a bug where `query_index'
    %% is not reset, causing consistent queries to hang
    _ = ra:stop_server(id(Cluster)),
    _ = ra:process_command(members(Cluster), {'nodedown', node()}),
    'ok'.

-spec available_nodes(cluster()) -> [node()].
available_nodes(Cluster) ->
    {'ok', Members, _Leader} = ra:members(id(Cluster)),
    lists:usort([Node || {_, Node} <- Members, lists:member(Node, nodes())]).