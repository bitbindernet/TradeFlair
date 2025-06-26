CREATE VIEW `redditbot`.`unconfirmedTradeLog` AS
with
    `confirmations` as (
        select
            `redditbot`.`messages`.`redditId` AS `MessageId`,
            `redditbot`.`messages`.`redditParentId` AS `ParentMessageId`,
            (
                lower(`redditbot`.`messages`.`body`) like '%confirmed%'
            ) AS `LOWER(body) LIKE '%confirmed%'`,
            `redditbot`.`messages`.`body` AS `body`,
            `redditbot`.`messages`.`created` AS `created`,
            `redditbot`.`users`.`redditId` AS `Username`
        from (
                `redditbot`.`messages`
                join `redditbot`.`users` on (
                    (
                        `redditbot`.`messages`.`userId` = `redditbot`.`users`.`id`
                    )
                )
            )
        where (
                (
                    `redditbot`.`messages`.`tradeThreadId` = 2
                )
                and (
                    lower(`redditbot`.`messages`.`body`) like '%confirmed%'
                )
                and (
                    `redditbot`.`messages`.`redditParentId` is not null
                )
                and (
                    `redditbot`.`messages`.`redditParentId` <> ''
                )
            )
    ),
    `top_level_comments` as (
        select
            `redditbot`.`messages`.`redditId` AS `MessageId`,
            `redditbot`.`messages`.`redditParentId` AS `ParentMessageId`,
            `redditbot`.`messages`.`body` AS `body`,
            `redditbot`.`messages`.`created` AS `created`,
            `redditbot`.`users`.`id` AS `userID`,
            `redditbot`.`users`.`redditId` AS `Username`
        from (
                `redditbot`.`messages`
                join `redditbot`.`users` on (
                    (
                        `redditbot`.`messages`.`userId` = `redditbot`.`users`.`id`
                    )
                )
            )
        where (
                (
                    `redditbot`.`messages`.`tradeThreadId` = 2
                )
                and (
                    (
                        `redditbot`.`messages`.`redditParentId` is null
                    )
                    or (
                        `redditbot`.`messages`.`redditParentId` = ''
                    )
                )
            )
    ),
    `trade_log` as (
        select
            `t`.`MessageId` AS `topLevelMessage`,
            `c`.`MessageId` AS `confirmingMessage`,
            `t`.`Username` AS `commentingUser`,
            `c`.`Username` AS `taggedUser`,
            `t`.`body` AS `body`,
            `c`.`body` AS `confirmation`
        from (
                `confirmations` `c`
                join `top_level_comments` `t` on (
                    (
                        `c`.`ParentMessageId` = `t`.`MessageId`
                    )
                )
            )
    ),
    `addedIds` as (
        select `redditbot`.`messages`.`redditParentId` AS `redditParentId`
        from `redditbot`.`messages`
        where (
                (
                    `redditbot`.`messages`.`body` like '%added%'
                )
                and (
                    `redditbot`.`messages`.`tradeThreadId` = 2
                )
            )
    )
select
    `tl`.`topLevelMessage` AS `topLevelMessage`,
    `tl`.`confirmingMessage` AS `confirmingMessage`,
    `tl`.`commentingUser` AS `commentingUser`,
    `tl`.`taggedUser` AS `taggedUser`,
    `tl`.`body` AS `body`,
    `tl`.`confirmation` AS `confirmation`,
    `m`.`id` AS `id`,
    `m`.`created` AS `created`
from (
        (
            `trade_log` `tl`
            left join `addedIds` `ai` on (
                (
                    `ai`.`redditParentId` = `tl`.`confirmingMessage`
                )
            )
        )
        join `redditbot`.`messages` `m` on (
            (
                `tl`.`topLevelMessage` = `m`.`redditId`
            )
        )
    )
where (`ai`.`redditParentId` is null);