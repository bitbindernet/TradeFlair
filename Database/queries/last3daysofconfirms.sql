SELECT CONCAT("https://www.reddit.com/r/Currencytradingcards/comments/1456rzb/comment/",redditParentId,"/"),json
FROM messages 
WHERE created > (NOW() - INTERVAL 72 HOUR)
  AND (json IS NULL OR json NOT LIKE '%Added%') and BODY like '%confirmed%';


SELECT CONCAT("https://www.reddit.com/r/Currencytradingcards/comments/1456rzb/comment/",redditParentId,"/"),json
FROM messages 
WHERE (json IS NULL OR json NOT LIKE '%Added%') and BODY like '%confirmed%';
