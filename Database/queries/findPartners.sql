
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
filterTable as (
select * From trade_log
where commentingUser <> taggedUser AND body LIKE CONCAT('%u/', taggedUser, '%')
),
partner_pairs as (
 Select commentingUser as user, taggedUser as trade_partner
 from filterTable
 UNION
 select taggedUser as user, commentingUser as trade_partner
 from filterTable
)
SELECT user, GROUP_CONCAT(trade_partner ORDER BY trade_partner SEPARATOR ', ') AS trade_partners
FROM partner_pairs
GROUP BY user;
