WITH RECURSIVE added_chain AS (
  SELECT id, redditId, redditParentId, 0 AS depth
  FROM messages
  WHERE tradeThreadId = 2
    AND body LIKE '%added%'

  UNION ALL
  SELECT m.id, m.redditId, m.redditParentId, ac.depth + 1
  FROM messages AS m
  JOIN added_chain AS ac
    ON m.redditId = ac.redditParentId
  WHERE ac.depth < 2
)
SELECT CONCAT("https://www.reddit.com/r/Currencytradingcards/comments/1456rzb/comment/",m.redditParentId,"/"),created
FROM messages AS m
LEFT JOIN added_chain AS ac
  ON m.id = ac.id
WHERE m.tradeThreadId = 2
  AND ac.id IS NULL
  AND m.redditParentId <> ''
  AND m.created > NOW() - INTERVAL 48 HOUR
ORDER BY m.created ASC

LIMIT 10000;
