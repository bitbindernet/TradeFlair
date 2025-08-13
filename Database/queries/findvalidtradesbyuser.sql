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

select m2.created, commentingUser, taggedUser, m2.body as trade, m1.body as confirmation, CONCAT((select url from tradethreads where id = m2.tradeThreadId),m2.redditId,"/") as link from trade_log 
join messages m1 on trade_log.confirmingMessage = m1.redditId
join messages m2 on trade_log.topLevelMessage = m2.redditId
join tradethreads on m2.tradeThreadId = tradethreads.id
where 
commentingUser = 'bitbindergaming' or taggedUser = 'bitbindergamingr';