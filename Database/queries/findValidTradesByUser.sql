
WITH
confirmations as (
SELECT messages.`redditId` as MessageId,`redditParentId` as ParentMessageId,LOWER(body) LIKE '%confirmed%',body,created, users.`redditId` as Username FROM messages
JOIN users on messages.`userId` = users.id
where tradeThreadId = 2 and LOWER(body) LIKE '%confirmed%' and (`redditParentId` is not null and `redditParentId` <> '')),
top_level_comments as (
SELECT messages.`redditId` as MessageId,`redditParentId` as ParentMessageId,body,created, users.id as userID ,users.`redditId` as Username
FROM messages
JOIN users on messages.`userId` = users.id
where tradeThreadId = 2 and (`redditParentId` is null or `redditParentId` = '')),
trade_log as (
select t.MessageId as topLevelMessage, c.MessageId as confirmingMessage, t.Username as commentingUser, c.Username as taggedUser, t.body, c.body as confirmation
FROM confirmations c
JOIN top_level_comments t on c.ParentMessageId = t.MessageId
where t.Username <> c.Username AND t.body LIKE CONCAT('%u/', c.Username, '%')
)
#select 'BitbinderGaming' as User, partners
select commentingUser, taggedUser from trade_log where 
commentingUser = 'BitbinderGaming' or taggedUser = 'BitbinderGaming';

#select * from trade_log where 
#commentingUser = 'BitbinderGaming' or taggedUser = 'BitbinderGaming'

#select Username, topLevelMessage, confirmingMessage, body, confirmation
#FROM (
#    SELECT commentingUser as Username, topLevelMessage, '' as confirmingMessage, body, '' as confirmation from trade_log
#    UNION ALL
#    SELECT taggedUser as Username, topLevelMessage, confirmingMessage, '' as body, confirmation from trade_log
#) as flair
#where Username = 'BitbinderGaming'

/*
CREATE TABLE materialized_trade_log AS
SELECT * FROM trade_log;
*/

