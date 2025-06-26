select  CONCAT("https://www.reddit.com/r/Currencytradingcards/comments/1456rzb/comment/",redditId,"/"), messages.* From messages where body like '%confirmed%' and redditParentId = '' and created > 05-01-2025;

 and 'redditParentId' = '';
select * From messages where body like '%confirmed%' and `redditParentId` is null;