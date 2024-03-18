-module(rss_queue).
-export([start/0, server/1, add_item/2, add_feed/2, get_all/1]).

% Макроопределения лог-сообщений
-define(INFO(Format, Data),
    error_logger:info_msg("~p ~p:  " ++ Format, [?MODULE, self()] ++ Data)).
-define(WARN(Format, Data),
    error_logger:warning_msg("~p ~p:  " ++ Format, [?MODULE, self()] ++ Data)).
-define(ERROR(Format, Data),
	error_logger:error_msg("~p ~p:  " ++ Format, [?MODULE, self()] ++ Data)).

% Таймаут на время ожижания приема сообщений = 10 с.
-define(TIMEOUT,10000).


% @type rssDoc() = #xmlElement{name=rss,
% attributes=[xmlAttr()],
% content=[xmlAny()]}.
% Корневой элемент xmerl ленты новостей RSS 2.0.
% @type rssItem() = #xmlElement{name=item}.
% Элемент ленты новостей RSS 2.0.
% @type filename() = string().
% Название файла.

% @doc Функция для запуска нового серверного процесса, обслуживающего очередь,
%      возвращает Pid созданного процесса.
% @spec start() -> pid()
%
start() ->
	Q = [],
	spawn(?MODULE,server,[Q]).


% @doc Функция, реализующая цикл сервера процесса очереди RSS, обрабатывающая
%      сообщения двух типов: {add_item,RSSItem} и {get_all,ReqPid}.
% @spec server([rssItem()]) -> ok 
%
server(Q) ->
	receive
		{add_item,RSSItem} ->
	    	NewQ = add_item_to_q(RSSItem,Q), 
	    	SortQ = sort(NewQ),
	    	server(SortQ);

	    {get_all,ReqPid} ->
	      	ReqPid ! {self(),Q},
	      	?INFO("Sent rss items to ~p~n",[ReqPid]),
	      	server(Q);

	    _Msg -> ?ERROR("Unknown message: ~p~n",[_Msg]), {unknown_msg,_Msg}
	end.


% @doc Вспомогательная функция, упрощающая процедуру отправки элемента в очередь;
%      QPid - это PID процесса очереди, а Item - это элемент добавляемый к очереди.
% @spec add_item(QPid::pid(), Item::rssItem()) -> ok
%
add_item(QPid, Item) when is_pid(QPid) ->
 	QPid ! {add_item, Item}, ok.

% @doc Эта функция должна извлекать все элементы из документа ленты, 
% и отправлять все элементы по порядку в очередь.
% @spec add_feed(QPid::pid(), RSS2Feed::rssDoc()) -> ok | error
%
add_feed(QPid,RSS2Feed) when is_pid(QPid) ->
	case rss_parse:is_rss2_feed(RSS2Feed) of
		true ->
			Items = rss_parse:get_feed_items(RSS2Feed),
			[add_item(QPid,Item) || Item <- Items],
			io:format("Size of RSS2Feed: ~p ~n", [length(Items)]),
			ok;
		false ->
			?ERROR("Version not 2.0! PID: ~p~n", [QPid]),
			error
	end.

% @doc Эта вспомогательная функция упрощает процедуру получения списка элементов 
%      ленты от процесса.
% @spec get_all(QPid::pid()) -> {ok, [rssItem()]} | {error,unknown_msg, string()} | {error,timeout}
%
get_all(QPid) when is_pid(QPid) ->
 	QPid ! {get_all, self()},
 	receive
 		{QPid, Q} -> 
 			io:format("Queue size = ~p items from the feed to ~p ~n", [length(Q),QPid]), 
 			{ok, Q};
 		_Msg -> ?ERROR("Unknown message: ~p~n",[_Msg]), {unknown_msg,_Msg}
 	after 
 		?TIMEOUT -> 
 			?ERROR("Timeout exceeded: module ~p, ~p in line ~p.~n", 
 					[?MODULE_STRING, ?FUNCTION_NAME, ?LINE]),
 			{error,timeout}
 	end.

% @private
% @doc Вспомогательная функция инициирующая процесс добавления 
%      нового элемента ленты в очередь.
% @spec add_item_to_q(NewItem::rssItem(), Q::[rssItem()]) -> [rssItem()]
%
add_item_to_q(NewItem, Q) ->
	add_item_to_q(NewItem, [], Q).

% @private
% @doc Вспомогательная функция, осуществляющая добавление 
%      нового элемента в пустую очередь.
% @spec add_item_to_q(NewItem::rssItem(), L1::[rssItem()], []) -> [rssItem()]
%
add_item_to_q(NewItem, L1, []) ->
	?INFO("New item added to Queue. PID: ~p~n", [self()]), 
	L1++[NewItem];

% @private
% @doc Вспомогательная функция, осуществляющая добавление 
%      нового элемента в непустую очередь по правилу:
%      если при сравнении получен атом same - новый элемент отбрасывается,
%      если получен атом updated - старая запись удаляется, а новая записывается соответственно дате,
%      если получен атом different - новый элемент добавляем в порядке возрастания даты.
% @spec add_item_to_q(NewItem::rssItem(), L1::[rssItem()], L::[rssItem()]) -> [rssItem()]
%
add_item_to_q(NewItem, L1, L = [OldItem | Rest]) ->
	case rss_parse:compare_feed_items(OldItem, NewItem) of
		same -> 
			?INFO("Same items. Item ignored. PID: ~p~n",[self()]),
			L1++L;
		updated -> 
			?INFO("Updated item. PID: ~p~n",[self()]),
			L1++Rest++[NewItem];
		different -> 
			add_item_to_q(NewItem, L1++[OldItem], Rest)
	end.

% @private
% @doc Функция сортировки списка элементов очереди
%      по возрастанию даты публикации.
% @spec sort([rssItem()]) -> [rssItem()]
%
sort([]) -> [];
sort([H|T]) -> sort([X || X <- T, rss_parse:get_item_time(X) < rss_parse:get_item_time(H)]) 
					++ [H] 
					++ sort([X || X <-T , rss_parse:get_item_time(X) >= rss_parse:get_item_time(H)]).
