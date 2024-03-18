-module(test).
-export([test1/1, test2/2, print_list/1]).

% Макроопределения лог-сообщений
-define(INFO(Format, Data),
    error_logger:info_msg("~p ~p:  " ++ Format, [?MODULE, self()] ++ Data)).
-define(WARN(Format, Data),
    error_logger:warning_msg("~p ~p:  " ++ Format, [?MODULE, self()] ++ Data)).
-define(ERROR(Format, Data),
	error_logger:error_msg("~p ~p:  " ++ Format, [?MODULE, self()] ++ Data)).

% @type rssDoc() = #xmlElement{name=rss,
% attributes=[xmlAttr()],
% content=[xmlAny()]}.
% Корневой элемент xmerl ленты новостей RSS 2.0.
% @type rssItem() = #xmlElement{name=item}.
% Элемент ленты новостей RSS 2.0.
% @type filename() = string().
% Название файла.


% @doc Test1: Загрузка в очередь XML файла.
% @spec test1(RSSFile::filename()) -> ok | {unknown_msg | error, string() | timeout}
%
test1(RSSFile) ->
	PID = rss_queue:start(),
	test_file_load(PID, RSSFile),
	exit(PID, kill).

% @doc Test2: Загрузка двух файлов с различными временами
% @spec test2(RSSFile1::filename(),RSSFile2::filename()) -> ok | {unknown_msg | error, string() | timeout}
%
test2(RSSFile1, RSSFile2) ->
	PID = rss_queue:start(),
	test_file_load(PID, RSSFile1),
	test_file_load(PID, RSSFile2),
	exit(PID, kill).

% @private
% @doc Вспомогательная функция для считывания элементов RSS ленты 
%      из XML файла, отправки их в RSS очередь и печати измененной очереди.
% @spec test_file_load(PID::pid(), RSSFile::filename()) -> ok | {unknown_msg | error, string() | timeout}
%
test_file_load(PID, RSSFile) ->
	XML = xmerl_scan:file(RSSFile),
	Ret = rss_queue:add_feed(PID, XML),
	case Ret of
		ok ->
			{Resp, Q} = rss_queue:get_all(PID),
			case Resp of
				ok -> print_list(Q), ok;
				_ -> {Resp, Q}
			end;
		_Else -> {version_err, _Else}
	end.
	
% @doc Функция печати очереди RSS, вызывающая 
%      высопомгательную функцию с итератером.
% @spec print_list(List::[rssItem()]) -> ok
%
print_list(List) -> io:format("~nQueue: ~n"), print_list(List, 1).

% @private
% @doc Вспомогательная функция печати очереди RSS, осуществляющая 
%      вывод сожержимого полей Guid, Title, Link и PubDate для каждого элемента.
% @spec print_list([rssItem()], Num::integer()) -> ok
%
print_list([], _) -> ok;
print_list([H | Rest], Num) ->
	[Guid, Title, Link, PubDate] = rss_parse:extract_feed_item_data(H),
	io:format("Item #~p:~n", [Num]),
	io:format("  Guid: ~p,~n  Title: ~p,~n  Link: ~p,~n  PubDate: ~p.~n", [Guid, Title, Link, PubDate]),
	print_list(Rest, Num + 1).
