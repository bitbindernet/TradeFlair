SELECT CONCAT("https://www.reddit.com/r/Currencytradingcards/comments/1456rzb/comment/", a.redditId, "/") AS url, a.created
FROM messages a
WHERE a.redditId NOT IN (
    SELECT m.redditParentId
    FROM messages m
    JOIN (
        SELECT redditParentId
        FROM messages
        WHERE MATCH(body) AGAINST('+added' IN BOOLEAN MODE)
    ) added ON m.redditId = added.redditParentId
    WHERE m.tradeThreadId = 2
)
AND EXISTS (
    SELECT 1
    FROM messages r
    WHERE r.redditParentId = a.redditId
    AND r.tradeThreadId = 2
    AND LOWER(r.body) LIKE '%confirmed%'
)
AND a.tradeThreadId = 2
AND (a.redditParentId IS NULL OR a.redditParentId = '')