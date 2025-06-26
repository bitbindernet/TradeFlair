select CONCAT("https://www.reddit.com/r/Currencytradingcards/comments/1456rzb/comment/",a.redditId,"/"),a.created from messages a where a.redditId not in (
select m.redditParentId From messages m join (
select redditParentId, body From messages
WHERE MATCH(body) AGAINST('+added' IN BOOLEAN MODE)
) added on m.redditId = added.redditParentId 
AND tradeThreadId = 2
)
and tradeThreadId = 2 and (redditParentId is null or redditParentId = '')