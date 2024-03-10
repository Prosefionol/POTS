-module(rss_parse).
-include_lib("xmerl/include/xmerl.hrl").
-import(xmerl_xpath, [string/2]).
-export([is_rss2_feed/1, get_feed_items/1, get_item_time/1, compare_feed_items/2, extract_feed_item_data/1]).

% @type rssDoc() = #xmlElement{name=rss,
% attributes=[xmlAttr()],
% content=[xmlAny()]}.
% Корневой элемент xmerl ленты новостей RSS 2.0.
% @type rssItem() = #xmlElement{name=item }.
% Элемент ленты новостей RSS 2.0.


% @doc Эта вспомогательная функция определяет соответствие
%      формата разобранного XML документа формату RSS 2.0
%
% Test:
% > rss_parse:is_rss2_feed(xmerl_scan:file("file_name.xml")).
%
% @spec is_rss2_feed(rssDoc()) -> bool()
%
is_rss2_feed(N) ->
    {XML,_} = N, xmerl_xpath:string("/rss[@version='2.0']", XML) /= [].

% @doc Эта функция возвращает список элементов ленты RSS.
%
% Test:
% > ItemList = rss_parse:get_feed_items(xmerl_scan:file("file_name.xml")).
%
% @spec get_feed_items(rssDoc()) -> [rssItem()]
%
get_feed_items(N) ->
    {RSS2Feed,_} = N, xmerl_xpath:string("//item", RSS2Feed).

% @doc Эта функция возвращает извлеченное из элемента ленты время публикации 
%      и целое число секунд отсчитанное с 0 года по григорианскому календарю.
%
% Test:
% > [Item1| _] = rss_parse:get_feed_items(xmerl_scan:file("file_name.xml")).
% > rss_parse:get_item_time(Item1).
%
% @spec get_item_time(rssItem()) -> integer() | bad_date
%
get_item_time(Item) ->
    [Time] = xmerl_xpath:string("/item/pubDate/text()", Item),
    Date = httpd_util:convert_request_date(Time#xmlText.value),
    calendar:datetime_to_gregorian_seconds(Date).

% @doc Эта функция сравнивает возвращает атом, 
% созданный на основе сравнения старых и новых элементов ленты:
% - same - если элементы равны,
% - updated - если новый элемент это обновление старого,
% - different - если элементы разные.
%
% Test:
% > [X1, X2| _] = rss_parse:get_feed_items(xmerl_scan:file("file_name.xml")).
% > [rss_parse:compare_feed_items(X1, X2), rss_parse:compare_feed_items(X1, X1)].
%
% @spec compare_feed_items(OldItem::rssItem(), NewItem::rssItem()) -> same | updated | different
%
compare_feed_items(OldItem, NewItem) when 
          is_record(OldItem, xmlElement),
          is_record(NewItem, xmlElement) ->
    Item1 = extract_xml(OldItem),
    Item2 = extract_xml(NewItem),
    [Guid1, Title1, Link1, PubDate1] = extract_feed_item_data(Item1),
    [Guid2, Title2, Link2, PubDate2] = extract_feed_item_data(Item2),
    compare_feed_items_data(Guid1, Title1, Link1, PubDate1, Guid2, Title2, Link2, PubDate2).

% @doc Эта вспомогательная функция, извлекающая поля элемента ленты 
%      и возвращающая их список.
%
% @spec extract_feed_item_data(rssItem()) -> [string()]
%
extract_feed_item_data(Item) when is_record(Item, xmlElement) ->
    [Guid] = xmerl_xpath:string("guid/text()", Item),
    [Title] = xmerl_xpath:string("title/text()", Item),
    [Link] = xmerl_xpath:string("link/text()", Item),
    [PubDate] = xmerl_xpath:string("pubDate/text()", Item),
    [Guid#xmlText.value, Title#xmlText.value, Link#xmlText.value, PubDate#xmlText.value].


% @private
% @doc Эта вспомогательная функция, обеспечивающая сравнение полей двух элементов
%
compare_feed_items_data(Guid, Title, Link, PubDate, Guid, Title, Link, PubDate) ->
    same;
compare_feed_items_data(Guid, _, _, _, Guid, _, _, _) ->
    updated;
compare_feed_items_data(_, Title, _, _, _, Title, _, _) ->
    updated;
compare_feed_items_data(_, _, Link, _, _, _, Link, _) ->
    updated;
compare_feed_items_data(_, _, _, _, _, _, _, _) ->
    different.

% @private
% @doc Эта вспомогательная функция просматривает заданный XML элемент
%      и удаляет из него сведения о других XML элементах, например содержащиеся в полях
%      "parents" или "pos".
%
% @spec extract_xml(Node::xmlAny()) -> xmlAny()
%
extract_xml(Elem = #xmlElement{}) ->
    Elem#xmlElement{parents=[], pos=0,
        content=lists:map(fun extract_xml/1, Elem#xmlElement.content),
        attributes=lists:map(fun extract_xml/1, Elem#xmlElement.attributes)};
extract_xml(Attr = #xmlAttribute{}) ->
    Attr#xmlAttribute{parents=[], pos=0};
extract_xml(Text = #xmlText{}) ->
    Text#xmlText{parents=[], pos=0};
extract_xml(Comment = #xmlComment{}) ->
    Comment#xmlComment{parents=[], pos=0};
extract_xml(Other) ->
    Other.
