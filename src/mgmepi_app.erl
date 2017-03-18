-module(mgmepi_app).

-include("internal.hrl").

%% -- public --
-behaviour(application).
-export([start/2, stop/1]).

%% == public ==

%% -- behaviour: application --

start(StartType, []) ->
    baseline_app:start(StartType, [
                                   {sup, [
                                          {local, mgmepi_sup},
                                          {
                                            {one_for_one, 10, timer:seconds(1)},
                                            get_childspecs(get_all_env())
                                          }
                                         ]}
                                  ]).

stop(State) ->
    baseline_app:stop(State).

%% == internal ==

get_all_env() ->
    application:get_all_env(get_application()).

get_application() ->
    element(2, application:get_application()).

get_childspecs(Args) ->
    [ get_childspec(E, Args) ||
        E <- proplists:get_value(connect, Args, [{"localhost", 1186}]) ].

get_childspec({A, P}, Args)
  when is_list(A), is_integer(P) ->
    {
      {A, P},
      {
        supervisor,
        start_link,
        [
         baseline_app,
         {
           {simple_one_for_one, 10, timer:seconds(5)},
           [
            {
              undefined,
              {
                mgmepi_client,
                start_link,
                [
                 [
                  A,
                  P,
                  proplists:get_value(options, Args, []),
                  proplists:get_value(timeout, Args, timer:seconds(3))
                 ]
                ]
              },
              temporary,
              timer:seconds(5),
              worker,
              []
            }
           ]
         }
        ]
      },
      permanent,
      timer:seconds(5),
      supervisor,
      []
    };
get_childspec(A, Args)
  when is_list(A) ->
    get_childspec({A, 1186}, Args).
