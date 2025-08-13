use redditbot;
drop view unaddedConfirmedTrades;
create view unaddedConfirmedTrades as(
WITH
confirmations AS (
  SELECT m.id AS confirmationId,
         m.redditId AS confirmingMessageId,
         m.redditParentId AS topLevelId,
         u.redditId AS confirmer,
         m.tradeThreadId
  FROM messages m
  JOIN users u ON u.id = m.userId
  WHERE m.tradeThreadId = 2 AND LOWER(m.body) LIKE '%confirmed%'
),

top_level AS (
  SELECT m.id AS topLevelDbId,
         m.redditId AS topLevelRedditId,
         u.redditId AS op
  FROM messages m
  JOIN users u ON u.id = m.userId
  WHERE m.tradeThreadId = 2 AND (m.redditParentId IS NULL OR m.redditParentId = '')
),

reply_chain AS (
  SELECT m.id AS replyId,
         m.redditId,
         m.redditParentId,
         u.redditId AS replyAuthor,
         m.body,
         m.tradeThreadId
  FROM messages m
  JOIN users u ON u.id = m.userId
  WHERE m.tradeThreadId = 2
),

flagged_threads AS (
  SELECT DISTINCT c.confirmationId
  FROM confirmations c
  JOIN top_level t ON t.topLevelRedditId = c.topLevelId
  JOIN reply_chain r ON r.redditParentId IN (c.confirmingMessageId, c.topLevelId)
  WHERE LOWER(r.body) LIKE '%added%'
    AND r.replyAuthor NOT IN (t.op, c.confirmer)
)

SELECT m.redditParentId,c.confirmationId,CONCAT("https://www.reddit.com/r/Currencytradingcards/comments/1456rzb/comment/",m.redditParentId,"/"),m.created
FROM messages m
JOIN confirmations c ON m.id = c.confirmationId
LEFT JOIN flagged_threads f ON f.confirmationId = c.confirmationId
WHERE f.confirmationId IS NULL AND (m.redditParentId is not null and m.redditParentId <> '')
)