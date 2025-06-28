import-module simplysql;

. .\awsHelper.ps1 -prod   

$epoch3days = [int][double]::Parse(
     ((Get-Date).AddDays(-7).ToUniversalTime() - [datetime]'1970-01-01').TotalSeconds
)

$ss = ConvertTo-SecureString $ENV:MYSQL_PASSWORD -AsPlainText -Force
Open-mySqlConnection -ConnectionName redditbot -Server $ENV:MYSQL_SERVER -Port $ENV:MYSQL_SERVER_PORT -Database redditbot -credential $(New-Object -TypeName 'System.Management.Automation.PsCredential' -ArgumentList $ENV:MYSQL_USER,$ss)

$threads = Invoke-SqlQuery -Query "select * from tradethreads" -ConnectionName redditbot

$threads | %{
     #$ENV:REDDIT_ENV         = 
     #$ENV:RECOUNT_TRADES     =
     $ENV:TRADE_THREAD       = $_.url

     python3 .\Get-MessagesSince.py --out messages.json --since $epoch3Days --more-limit 1000
     . .\sync-messages.ps1

}
#if($prod){
#
#    $ENV:REDDIT_ENV         = "Production"
#    $ENV:RECOUNT_TRADES     = "true"
#    $ENV:TRADE_THREAD       = "https://www.reddit.com/r/Currencytradingcards/comments/1456rzb/reputation_confirmed_trades_thread/"
#
#}
#else {
#    $ENV:REDDIT_ENV = "non-prod"
#    $ENV:TRADE_THREAD = "https://www.reddit.com/r/CCAutoFlare/comments/1j4k61w/reputation_confirmed_trades_thread/"
#    $ENV:SUBREDDIT_NAME = "CCAutoFlare"
#}



. .\update-leaderboard.ps1