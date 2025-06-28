. ./awshelper.ps1 -prod
$credential = $(New-Object -TypeName 'System.Management.Automation.PsCredential' -ArgumentList $ENV:MYSQL_USER,$ss)
Open-mySqlConnection -ConnectionName redditbot -Server $ENV:MYSQL_SERVER -Port $ENV:MYSQL_SERVER_PORT -Database redditbot -credential $credential

$jsonTradeFlair = invoke-sqlquery -query "select JSON_OBJECTAGG(Username,TradeFlair) From calculatedTradeFlair" -ConnectionName redditbot
$jsonTradeFlair.'JSON_OBJECTAGG(Username,TradeFlair)' | set-content -Path ./tradeCountDisplay/trade_flair.json
aws s3 cp ./tradeCountDisplay/trade_flair.json s3://ccautoflair.bitbinder.net/trade_flair.json