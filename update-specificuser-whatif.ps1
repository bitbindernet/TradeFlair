param(
    $redditUser = 'ronniman'
);

import-module simplysql
. ./awshelper.ps1


$ss = ConvertTo-SecureString $ENV:MYSQL_PASSWORD -AsPlainText -Force
Open-mySqlConnection -ConnectionName redditbot -Server $ENV:MYSQL_SERVER -Port $ENV:MYSQL_SERVER_PORT -Database redditbot -credential $(New-Object -TypeName 'System.Management.Automation.PsCredential' -ArgumentList $ENV:MYSQL_USER,$ss)

$tradeFlairOverrides = Invoke-SqlQuery -Query "SELECT users.redditId,trade_thread_id,tradethreads.subreddit,override_text FROM redditbot.flair_override join users on flair_override.user_id = users.id join tradethreads on flair_override.trade_thread_id = tradethreads.id" -ConnectionName redditbot

$threads = Invoke-SqlQuery -Query "select * from tradethreads where active = 1" -ConnectionName redditbot

$userId = $(Invoke-SqlQuery -query "select id from users where redditId = @redditUser" -Parameters @{redditUser = $redditUser} -ConnectionName redditbot | select-object -ExpandProperty id)

$userTradeCount = $(Invoke-SqlQuery -query "select trade_count from flair where userid = @userId" -Parameters @{userId = $userId} -ConnectionName redditbot | select-object -ExpandProperty trade_count)

$tradeFlairCompare = @{
    $redditUser = @{"local"=@{"Trades"=$(if($userTradeCount -gt 0){$userTradeCount}else{0})}};
}

$threads | %{
    $currentThread = $_;
    write-warning "Downloading current flair for $redditUser on $($currentThread.Subreddit)"
    $UserFlairOnSubreddit     = Parse-FlairText $(python3 ./get-userflairbysubreddit.py $currentThread.subreddit $redditUser | convertfrom-json).$redditUser
    $tradeFlaircompare.$redditUser.add($currentThread.subreddit, $UserFlairOnSubreddit   )
}

$tradeFlairCompare.keys | %{

    $username = $_
    $highestCurrentFlair = $tradeFlairCompare.$username.values.trades | sort-object -Descending | Select-Object -first 1;

    $tradeFlairCompare.$username.keys |%{
        $toupdate = $_;

        switch($toupdate)
        {
            "local" {
                write-warning "$username local flair is $highestCurrentFlair"
            }
            default {
                if($tradeFlairOverrides | where-object {$_.redditId -eq $username}){
                    $overrideText = ($tradeFlairOverrides | where-object {$_.redditId -eq $username} | where-object {$_.subreddit -eq $toUpdate} | select-object -ExpandProperty override_text)
                    write-warning "User $username has an override of $overrideText"
                    $highestCurrentFlair = $overrideText
                }
                if($tradeFlairCompare.$username.$toUpdate.Emojis){
                    write-warning "User $username, has emojis in $toUpdate"
                    $Newflair = "Trades: $($highestCurrentFlair) :$($tradeFlairCompare.$username.$toUpdate.Emojis -join ":"):"
                }
                else
                {
                    write-warning "User $username, does not have emojis in $toUpdate"
                    $NewFlair = "Trades: $($highestCurrentFlair)"
                }
                write-warning "Setting $toUpdate --> $username --> $Newflair"
            }
        }
    }
}