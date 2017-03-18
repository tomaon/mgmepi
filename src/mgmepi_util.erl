-module(mgmepi_util).

-include("internal.hrl").

%% -- private --
-export([boolean_to_binary/1]).
-export([fold/2]).
-export([get_result/1, get_result/2]).
-export([get_value/2]).
-export([implode/3]).
-export([match/3]).
-export([parse/2, parse/3]).

%% == private ==

-spec boolean_to_binary(boolean()) -> <<_:8>>.
boolean_to_binary(true)  -> <<"1">>;
boolean_to_binary(false) -> <<"0">>.


-spec fold([function()], [term()]) -> [term()].
fold(List, Acc) ->
    F = fun(E, A) -> case E() of undefined -> A; T -> [T|A] end end,
    lists:reverse(lists:foldl(F, lists:reverse(Acc), List)).


-spec get_result([matched()]) -> ok|{error, _}.
get_result(List) ->
    case get_value(<<"result">>, List) of
        <<"Ok">> ->
            ok;
        Reason ->
            {error, Reason}
    end.

-spec get_result([matched()], binary()|[binary()]) -> {ok, term()}|{error, _}.
get_result(List, Other) when is_binary(Other) ->
    case get_value(<<"result">>, List) of
        <<"Ok">> ->
            {ok, get_value(Other, List)};
        Reason ->
            {error, Reason}
    end;
get_result(List, Other) when is_list(Other) ->
    case get_value(<<"result">>, List) of
        <<"Ok">> ->
            {ok, list_to_tuple([ get_value(E, List) || E <- Other ])};
        Reason ->
            {error, Reason}
    end.


-spec get_value(term(), [tuple()]) -> term().
get_value(Key, List) ->
    baseline_lists:get_value(Key, List).


-spec implode(function(), [term()], binary()) -> binary().
implode(Fun, List, Separator) ->
    baseline_binary:implode(Fun, List, Separator).


-spec match([param()], [parsed()], [matched()]) -> {ok, [matched()], [parsed()]}.
match([], Rest, List) ->
    {ok, lists:reverse(List), Rest};
match([{K, string, _}|L], [[K, V]|R], List) ->
    match(L, R, [{K, V}|List]);
match([{K, integer, _}|L], [[K, V]|R], List) ->
    match(L, R, [{K, binary_to_integer(V)}|List]);
match([{K, boolean, _}|L], [[K, V]|R], List) ->
    match(L, R, [{K, binary_to_boolean(V)}|List]);
match([{K, null, _}|L], [[K]|R], List) ->
    match(L, R, List);
match([{K, V, _}|L], [[K, V]|R], List) ->
    match(L, R, [{K, V}|List]);
match([{_, _, optional}|L], R, List) ->
    match(L, R, List).


-spec parse(binary(), [param()]) -> {ok, [matched()], [parsed()]}.
parse(Binary, Params) ->
    parse(Binary, Params, <<?FS>>).

-spec parse(binary(), [param()], binary()) -> {ok, [matched()], [parsed()]}.
parse(Binary, Params, FieldPattern) ->
    match(Params, baseline_binary:split(Binary, FieldPattern, <<?LS>>), []).


%% == internal ==

binary_to_boolean(<<"1">>) -> true;
binary_to_boolean(<<"0">>) -> false.
