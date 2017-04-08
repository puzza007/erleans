-module(erleans_dns_peers).

-export([join/0,
         leave/0]).

join() ->
    ClusterType = erleans_config:get(node_discovery, none),
    Port = erleans_config:get(partisan_port, 10200),
    NodeName = erleans_config:get(nodename, nonodename),
    AllNodes = lookup(ClusterType, NodeName, Port),
    ordsets:fold(fun({Name, Host, PartisanPort}, _) ->
                     erleans_cluster:join(Name, Host, PartisanPort)
                 end, ok, AllNodes),
    {ok, Members} = partisan_peer_service:members(),
    {lists:usort(Members), AllNodes}.

leave() ->
    ok.
    %% partisan_peer_service:leave([]).

lookup(local, _NodeName, _Port) ->
    ordsets:new();
lookup(manual, _NodeName, _Port) ->
    ordsets:new();
lookup(none, _NodeName, _Port) ->
    ordsets:new();
lookup({direct, Nodes}, _NodeName, _Port) ->
    ordsets:from_list(Nodes);
lookup({ip, DiscoveryDomain}, NodeName, Port) ->
    lists:foldl(fun(Record, NodesAcc) ->
                    H = inet_parse:ntoa(Record),
                    sets:add_element({list_to_atom(string:join([NodeName, H], "@")), H, Port}, NodesAcc)
                end, sets:new(), inet_res:lookup(DiscoveryDomain, in, a));
lookup({fqdns, DiscoveryDomain}, NodeName, Port) ->
    lists:foldl(fun(Record, NodesAcc) ->
                    {ok, {hostent, Host, _, _, _, _}} = inet_res:gethostbyaddr(Record),
                    sets:add_element({list_to_atom(string:join([NodeName, Host], "@")), Host, Port}, NodesAcc)
                end, sets:new(), inet_res:lookup(DiscoveryDomain, in, a));
lookup({srv, DiscoveryDomain}, NodeName, _) ->
    lists:foldl(fun({_, _, PartisanPort, Host}, NodesAcc) ->
                    Node = list_to_atom(atom_to_list(NodeName)++"@"++Host),
                    ordsets:add_element({Node, Host, PartisanPort}, NodesAcc)
                end, ordsets:new(), inet_res:lookup(DiscoveryDomain, in, srv)).
