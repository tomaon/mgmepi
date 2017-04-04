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
                                            {one_for_one, 10, 10},
                                            get_childspecs()
                                          }
                                         ]}
                                  ]).

stop(State) ->
    baseline_app:stop(State).

%% == internal ==

get_childspecs() ->
    get_childspecs(baseline_app:get_all_env()).

get_childspecs(Env) ->
    [ get_childspec(E, Env) ||
        E <- get_value(connect, Env, [{"localhost", 1186}]) ].

get_childspec({A, P}, Env)
  when is_list(A), is_integer(P) ->
    {
      {A, P},
      {
        supervisor,
        start_link,
        [
         baseline_app,
         {
           {simple_one_for_one, 10, 10},
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
                  get_value(options, Env, []),
                  get_value(timeout, Env, 5000)
                 ],
                 [
                  {spawn_opt, get_value(spawn_opt, Env, [])}
                 ]
                ]
              },
              temporary,
              5000,
              worker,
              []
            }
           ]
         }
        ]
      },
      permanent,
      5000,
      supervisor,
      []
    };
get_childspec(A, Args)
  when is_list(A) ->
    get_childspec({A, 1186}, Args).


get_value(Key, List, Default) ->
    baseline_lists:get_value(Key, List, Default).
