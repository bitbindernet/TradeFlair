CREATE OR REPLACE VIEW `redditbot`.`effectiveTradeFlair` AS

SELECT
    ctf.Username,
    ctf.TradeFlair + COALESCE(u.tradeFlairOffset, 0) AS EffectiveTradeFlair
FROM
    `redditbot`.`calculatedTradeFlair` ctf
LEFT JOIN
    `redditbot`.`users` u
ON
    ctf.Username = u.redditId;
