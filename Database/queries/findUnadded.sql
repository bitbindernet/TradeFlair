SELECT
  CONCAT("https://www.reddit.com/r/Currencytradingcards/comments/1456rzb/comment/",m.redditId,"/"),m.created
FROM
  messages AS m
  LEFT JOIN (
    SELECT id, redditId
    FROM messages
    WHERE MATCH(body) AGAINST('+added' IN BOOLEAN MODE)
    
  ) AS am ON am.id = m.id
  LEFT JOIN messages AS cm
    ON cm.redditParentId = am.redditId
  LEFT JOIN messages AS pm
    ON pm.redditParentId = cm.redditId
WHERE
  m.tradeThreadId = 2
  AND am.id IS NULL
  AND cm.id IS NULL
  AND pm.id IS NULL
  AND m.created > NOW() - INTERVAL 48 HOUR
  AND m.redditParentId IS NOT NULL
LIMIT 10000;