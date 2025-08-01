CREATE VIEW `redditbot`.`calculatedTradeFlair` AS 
with `confirmations` as
(
    select `redditbot`.`messages`.`redditId` AS `MessageId`,`redditbot`.`messages`.`redditParentId` AS `ParentMessageId`,(lower(`redditbot`.`messages`.`body`) like '%confirmed%') AS `LOWER(body) LIKE '%confirmed%'`,`redditbot`.`messages`.`body` AS `body`,`redditbot`.`messages`.`created` AS `created`,`redditbot`.`users`.`redditId` AS `Username` 
    from (`redditbot`.`messages` join `redditbot`.`users` on((`redditbot`.`messages`.`userId` = `redditbot`.`users`.`id`))) 
    where ((`redditbot`.`messages`.`tradeThreadId` = 2) and (lower(`redditbot`.`messages`.`body`) like '%confirmed%') and (`redditbot`.`messages`.`redditParentId` is not null) and (`redditbot`.`messages`.`redditParentId` <> ''))
), 
`top_level_comments` as (
    select `redditbot`.`messages`.`redditId` AS `MessageId`,`redditbot`.`messages`.`redditParentId` AS `ParentMessageId`,`redditbot`.`messages`.`body` AS `body`,`redditbot`.`messages`.`created` AS `created`,`redditbot`.`users`.`id` AS `userID`,`redditbot`.`users`.`redditId` AS `Username` 
    from (`redditbot`.`messages` join `redditbot`.`users` on((`redditbot`.`messages`.`userId` = `redditbot`.`users`.`id`))) 
    where ((`redditbot`.`messages`.`tradeThreadId` = 2) and ((`redditbot`.`messages`.`redditParentId` is null) or (`redditbot`.`messages`.`redditParentId` = '')))
), 
`trade_log` as (
    select `t`.`MessageId` AS `topLevelMessage`,
        `c`.`MessageId` AS `confirmingMessage`,`t`.`Username` AS `commentingUser`,`c`.`Username` AS `taggedUser`,`t`.`body` AS `body`,`c`.`body` AS `confirmation` 
        from (`confirmations` `c` join `top_level_comments` `t` on((`c`.`ParentMessageId` = `t`.`MessageId`)))
), 
`filterTable` as (
    select `trade_log`.`topLevelMessage` AS `topLevelMessage`,`trade_log`.`confirmingMessage` AS `confirmingMessage`,`trade_log`.`commentingUser` AS `commentingUser`,`trade_log`.`taggedUser` AS `taggedUser`,`trade_log`.`body` AS `body`,`trade_log`.`confirmation` AS `confirmation` 
    from `trade_log` 
    where ((`trade_log`.`commentingUser` <> `trade_log`.`taggedUser`) and (`trade_log`.`body` like concat('%u/',`trade_log`.`taggedUser`,'%')))
) 
select `flair`.`Username` AS `Username`,count(0) AS `TradeFlair` 
from (
    select `filterTable`.`commentingUser` AS `Username` from `filterTable` 
    union all 
    select `filterTable`.`taggedUser` AS `Username` from `filterTable`) `flair` 
    where (`flair`.`Username` <> '[deleted]') group by `flair`.`Username` order by `TradeFlair` desc;
