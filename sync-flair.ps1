. .\awsHelper.ps1
$ss = ConvertTo-SecureString $ENV:MYSQL_PASSWORD -AsPlainText -Force
Open-mySqlConnection -ConnectionName redditbot -Server $ENV:MYSQL_SERVER -Port $ENV:MYSQL_SERVER_PORT -Database redditbot -credential $(New-Object -TypeName 'System.Management.Automation.PsCredential' -ArgumentList $ENV:MYSQL_USER,$ss)


$threads = Invoke-SqlQuery -Query "select * from tradethreads" -ConnectionName redditbot
$spaceUsers = Invoke-SqlQuery -Query "select * from messages join users on messages.userId = users.id where tradeThreadId = 2" -ConnectionName redditbot                                                                                             
$spaceusers.redditId1 | select -Unique | %{
    $currentUser=$_;
    $UserFlair = Invoke-SqlQuery -query "select * from flair where userId = (select id from users where redditId = @user)" -Parameters @{user=$currentUser} -ConnectionName redditbot;
    $userFlair; 
    python3 .\Set-UserFlair.py $threads[3].subreddit $currentUser "Trades: $($userflair.trade_count):upvote:" 
}  