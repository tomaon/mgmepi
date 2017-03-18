-ifndef(internal).
-define(internal, true).

-include("../include/mgmepi.hrl").

-include_lib("baseline/include/baseline.hrl").
%%nclude_lib("../.rebar3/default/lib/baseline/include/baseline.hrl").

%% == define ==
-define(NDB_VERSION_ID, 459523). % 0x070303

-define(FS, ": ").
-define(LS, $\n).

%% == type ==

-record(mgmepi, {
          sup     :: undefined|pid(),
          worker  :: undefined|pid(),
          link    :: boolean(),
          timeout :: timeout()
         }).

-type(mgmepi() :: #mgmepi{}).

-type(arg()     :: {binary(), binary()}).
-type(matched() :: {binary(), term()}).
-type(param()   :: {binary(), atom()|binary(), atom()}).
-type(parsed()  :: [binary()]).

-endif. % internal
