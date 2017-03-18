# mgmepi

[MySQL Cluster](https://dev.mysql.com/doc/refman/5.7/en/mysql-cluster.html) Management API (mgmapi) for Erlang

## Build

```bash
$ make all
```

## Example

```bash
% cat examples/conf/n1.config
%% -*- erlang -*-
[
 {mgmepi, [
           {connect, [
                      "127.0.0.1"
                     ]}
          ]}
].
% make n1
Eshell V8.2  (abort with ^G)
(n1@localhost)1> {ok, M} = mgmepi:checkout().
{ok,{mgmepi,<0.68.0>,<0.71.0>,true,60000}}
(n1@localhost)2> mgmepi:get_version(M).
{ok,460037}                                     % 460037=0x070505
(n1@localhost)3> mgmepi:checkin(M).
ok
(n1@localhost)4>
```
