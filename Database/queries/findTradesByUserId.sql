use redditbot;
select  CONCAT("https://www.reddit.com/r/Currencytradingcards/comments/1456rzb/comment/",messages.redditId,"/") as Link,users.redditId,body from messages join users on messages.userId = users.Id where userId =   @UserID and body like "%confirmed%"
UNION ALL
select CONCAT("https://www.reddit.com/r/Currencytradingcards/comments/1456rzb/comment/",messages.redditId,"/")    as Link,users.redditId,body From messages join users on messages.userId = users.Id where userId = @UserID and redditParentId = ''

select  CONCAT("https://www.reddit.com/r/Currencytradingcards/comments/1456rzb/comment/",messages.redditId,"/") as Link,users.redditId,body from messages join users on messages.userId = users.Id where userId =   @UserID and body like "%confirmed%" and messages.redditId in (select redditParentId from messages where body like "%added%")
UNION ALL
select CONCAT("https://www.reddit.com/r/Currencytradingcards/comments/1456rzb/comment/",messages.redditId,"/")    as Link,users.redditId,body From messages join users on messages.userId = users.Id where userId = @UserID and redditParentId = '' and messages.redditId in (select redditParentId from messages where body like "%confirmed%" and redditId in (select redditParentId from messages where body like "%added%"))