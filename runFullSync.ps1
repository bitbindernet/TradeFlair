import-module simplysql;

. .\awsHelper.ps1 -prod   

$ss = ConvertTo-SecureString $ENV:MYSQL_PASSWORD -AsPlainText -Force
Open-mySqlConnection -ConnectionName redditbot -Server $ENV:MYSQL_SERVER -Port $ENV:MYSQL_SERVER_PORT -Database redditbot -credential $(New-Object -TypeName 'System.Management.Automation.PsCredential' -ArgumentList $ENV:MYSQL_USER,$ss)

$threads = Invoke-SqlQuery -Query "select * from tradethreads" -ConnectionName redditbot

$threads | %{
     #$ENV:REDDIT_ENV         = 
     #$ENV:RECOUNT_TRADES     =
     $ENV:TRADE_THREAD       = $_.url

     python3 .\Get-AllMessagesSafe.py
     . .\sync-messages.ps1

}