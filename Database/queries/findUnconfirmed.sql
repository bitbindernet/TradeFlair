create view unconfirmedTradeLog as (

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
select t.MessageId topLevelMessage, c.MessageId confirmingMessage, t.Username as commentingUser, c.Username as taggedUser, t.body, c.body as confirmation
FROM confirmations c
JOIN top_level_comments t on c.ParentMessageId = t.MessageId
),
addedIds as (
select `redditParentId` From messages where body like '%added%' and `tradeThreadId` = 2
)
SELECT
    tl.*,
    m.id,
    m.created
FROM trade_log      tl
LEFT JOIN addedIds  ai
          ON ai.redditParentId = tl.confirmingMessage
join messages m on tl.topLevelMessage = m.redditId
WHERE ai.redditParentId IS NULL
)
#SELECT
#    CONCAT("https://www.reddit.com/r/Currencytradingcards/comments/1456rzb/comment/",confirmingMessage,"/")
#FROM trade_log      tl
#LEFT JOIN addedIds  ai
#          ON ai.redditParentId = tl.confirmingMessage
#WHERE ai.redditParentId IS NULL;