%% -*- erlang-indent-level: 4;indent-tabs-mode: nil; fill-column: 80 -*-
%% ex: ts=4 sw=4 et
%% @author Marc Paradise <marc@chef.io>
%% Copyright 2015 Chef Software, Inc.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
-module(oc_chef_wm_server_api_version_SUITE).

-include("../../../include/server_api_version.hrl").
-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

-compile([export_all, {parse_transform, lager_transform}]).

-define(ORG_NAME, <<"org1">>).
-define(ORG_AUTHZ_ID, <<"10000000000000000000000000000002">>).
-define(CLIENT_NAME, <<"test-client">>).
-define(CLIENT_AUTHZ_ID, <<"00000000000000000000000000000003">>).
-define(USER_NAME, <<"test-user">>).
-define(USER_AUTHZ_ID, <<"00000000000000000000000000000004">>).

all() ->
    [endpoint_gives_valid_response,
     version_not_specified_accepted,
     valid_min_version_accepted,
     valid_max_version_accepted,
     valid_in_range_version_accepted,
     invalid_version_too_high_rejected,
     invalid_version_too_low_rejected,
     invalid_version_bad_value_rejected].

init_per_suite(Config) ->
    Config2 = setup_helper:base_init_per_suite([{org_name, ?ORG_NAME}, {org_authz_id, ?ORG_AUTHZ_ID},
                                                {authz_id, ?CLIENT_AUTHZ_ID}, {client_name, ?CLIENT_NAME} | Config]),
    setup_helper:make_user(Config2, ?USER_NAME, ?USER_AUTHZ_ID),
    Config2.


end_per_suite(Config) ->
    {ok, 1} = sqerl:execute(<<"DELETE FROM users WHERE username = $1">>, [?USER_NAME]),
    setup_helper:base_end_per_suite(Config).

endpoint_gives_valid_response(_Config) ->
    {Code, EJ} = api_get("server_api_version", ?API_MIN_VER),
    ?assertEqual(Code, "200"),
    ?assertMatch(EJ, expected_version_endpoint_response()).

version_not_specified_accepted(_Config) ->
    % Here and below use an unrelated endpoint to test
    % cross-endpoint behavior
    {Code, _} = api_get("license", undefined),
    ?assertEqual(Code, "200").

invalid_version_too_high_rejected(_Config) ->
    TestVersion = ?API_MAX_VER + 1,
    {Code, EJ} = api_get("license", TestVersion),
    ?assertEqual(Code, "406"),
    ?assertMatch(EJ, expected_error_response(TestVersion)).

invalid_version_too_low_rejected(_Config) ->
    TestVersion = ?API_MIN_VER - 1,
    {Code, EJ} = api_get("license", TestVersion),
    ?assertEqual(Code, "406"),
    ?assertMatch(EJ, expected_error_response(TestVersion)).

invalid_version_blank_rejected(_Config) ->
    {Code, EJ} = api_get("license", ""),
    ?assertEqual(Code, "406"),
    ?assertMatch(EJ, expected_error_response("")).

invalid_version_bad_value_rejected(_Config) ->
    TestVersion = "nope",
    {Code, EJ} = api_get("license", TestVersion),
    ?assertEqual(Code, "406"),
    ?assertMatch(EJ, expected_error_response(TestVersion)).

valid_min_version_accepted(_Config) ->
    {Code, _} = api_get("license", ?API_MIN_VER),
    ?assertEqual(Code, "200").

valid_max_version_accepted(_Config) ->
    {Code, _} = api_get("license", ?API_MAX_VER),
    ?assertEqual(Code, "200").

valid_in_range_version_accepted(_Config) ->
    {Code, _} = api_get("license", ?API_MIN_VER + 1),
    ?assertEqual(Code, "200").

end_per_testcase(_, Config) ->
    Config.

expected_error_response(BadVersion) when is_integer(BadVersion) ->
    expected_error_response(integer_to_list(BadVersion));
expected_error_response(BadVersion) ->
    {[{<<"error">>, <<"invalid-x-ops-server-api-version">>},
      {<<"message">>, iolist_to_binary([ <<"Specified version ">>, BadVersion, <<" not supported">>])},
      {<<"min_version">>, ?API_MIN_VER},
      {<<"max_version">>, ?API_MAX_VER}]}.

expected_version_endpoint_response() ->
    {[{<<"min_api_version">>, ?API_MIN_VER},
      {<<"max_api_version">>, ?API_MAX_VER}]}.

api_get(Route, Version) ->
    {ok, Code, _Headers, ResponseBody} =  http_request(get, Route, Version),
    {Code, chef_json:decode(ResponseBody)}.

http_request(Method, Route, undefined) ->
    ibrowse:send_req("http://localhost:8000/" ++ Route,
                     [{"x-ops-userid", binary_to_list(?USER_NAME)},
                      {"accept", "application/json"},
                      {"content-type", "application/json"}], Method, []);
http_request(Method, Route, Version) ->
    ibrowse:send_req("http://localhost:8000/" ++ Route,
                     [{"x-ops-userid", binary_to_list(?USER_NAME)},
                      {"accept", "application/json"},
                      {"x-ops-server-api-version", Version},
                      {"content-type", "application/json"}], Method, []).

