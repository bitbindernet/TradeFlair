import-module simplysql
. ./awshelper.ps1


$ss = ConvertTo-SecureString $ENV:MYSQL_PASSWORD -AsPlainText -Force
Open-mySqlConnection -ConnectionName redditbot -Server $ENV:MYSQL_SERVER -Port $ENV:MYSQL_SERVER_PORT -Database redditbot -credential $(New-Object -TypeName 'System.Management.Automation.PsCredential' -ArgumentList $ENV:MYSQL_USER,$ss)

$threads = Invoke-SqlQuery -Query "select * from tradethreads where active = 1" -ConnectionName redditbot
$messages = invoke-sqlquery -query "select * from messages where tradeThreadId in (select id from tradethreads where active = 1) and created >= CURDATE() - INTERVAL 10 DAY " -ConnectionName redditbot
$tradeFlairOverrides = Invoke-SqlQuery -Query "SELECT users.redditId,trade_thread_id,tradethreads.subreddit,override_text FROM redditbot.flair_override join users on flair_override.user_id = users.id join tradethreads on flair_override.trade_thread_id = tradethreads.id" -ConnectionName redditbot
$messagesToProcess = $messages.Clone()
$filterMessages = $messages | Where-Object {$($_.body -match "confirm" -or $_.body -match "received")-and $_.redditParentId} 
foreach ($currentConfirmingMessage in $filterMessages){
    #$currentConfirmingMessage = $_;
    $currentConfirmingMessageId = $currentConfirmingMessage.redditId;
    $currentConfirmingMessageParentMessageId = $currentConfirmingMessage.redditParentId;
    $currentParentMessage = $messagesToProcess | Where-Object{$_.redditId -eq $currentConfirmingMessageParentMessageId};
    $currentParentMessageId = $currentParentMEssage.redditId;
    $parentUserId = $currentParentmessage.userId;
    $confirmingUserId = $currentConfirmingMessage.userId;
    
    if($parentUserId -eq $confirmingUserId){
        write-warning "Oops - You cannot confirm your own trade"
        continue;
    }

    $parentUserName = $(Invoke-SqlQuery -query "select redditId from users where id = @userId" -Parameters @{userId = $parentUserId} -ConnectionName redditbot | select-object -ExpandProperty redditId)
    $confirmingUserName = $(Invoke-SqlQuery -query "select redditId from users where id = @userId" -Parameters @{userId = $confirmingUserId} -ConnectionName redditbot | select-object -ExpandProperty redditId)
    
    if(-not $currentParentMessage.body -contains $confirmingUserName)
    {
        write-warning "Oops - you replied to someone who didn't tag you"
        continue;
    }
    
    $confirmingMessagesReplies = python3 ./get-replies.py --message-ids $currentConfirmingMessageId --stdout --json | convertfrom-json
    $TopLevelMessageReplies    = python3 ./get-replies.py --message-ids $currentParentMessageid --stdout --json | convertfrom-json

    if($confirmingMessagesReplies -match "added"){
        write-warning "Oops - This trade is already posted"
        continue;
    }
    if($TopLevelMessageReplies  -match "added"){
        write-warning "Oops - This trade is already confirmed"
        continue;
    }
    
    #get current user local flair count
    $parentUserTradeCount = $(Invoke-SqlQuery -query "select trade_count from flair where userid = @userId" -Parameters @{userId = $parentUserId} -ConnectionName redditbot | select-object -ExpandProperty trade_count)
    $ConfirmingUserTradeCount = $(Invoke-SqlQuery -query "select trade_count from flair where userid = @userId" -Parameters @{userId = $confirmingUserId} -ConnectionName redditbot | select-object -ExpandProperty trade_count)

    #foreach active thread, check users current flair against database
    $tradeFlairCompare = @{
        $parentUserName = @{"local"=@{"Trades"=$(if($parentUserTradeCount -gt 0){$parentUserTradeCount}else{0})}};
        $confirmingUsername = @{"local"=@{"Trades"=$(if($ConfirmingUserTradeCount -gt 0){$ConfirmingUserTradeCount}else{0})}}
    }
    $threads | %{
        $currentThread = $_;
        write-warning "Downloading current flair for $parentUsername on $($currentThread.Subreddit)"
        $currentParentUserFlairOnSubreddit     = Parse-FlairText $(python3 ./get-userflairbysubreddit.py $currentThread.subreddit $parentUserName | convertfrom-json).$parentUsername
        write-warning "Downloading current flair for $confirmingUserName on $($currentThread.Subreddit)"
        $currentConfirmingUserFlairOnSubreddit = Parse-FlairText $(python3 ./get-userflairbysubreddit.py $currentThread.subreddit $confirmingUserName | convertfrom-json).$confirmingUserName
        $tradeFlaircompare.$parentUserName.add($currentThread.subreddit,$currentParentUserFlairOnSubreddit)
        #$tradeFlaircompare.$parentUserName.add($($currentThread.subreddit),$currentParentUserFlairOnSubreddit.Emojis)
        $tradeFlairCompare.$confirmingUserName.add($currentThread.subreddit,$currentConfirmingUserFlairOnSubreddit)
        #$tradeFlairCompare.$confirmingUserName.add(@($currentThread.subreddit),$currentConfirmingUserFlairOnSubreddit.Emojis)
    }

    #writeback the highest flair +1 
    $tradeFlairCompare.keys | %{
        $username = $_;
        $highestCurrentFlair = $tradeFlairCompare.$username.values.trades | sort-object -Descending | Select-Object -first 1;
        $highestCurrentFlair++

        
        $tradeFlairCompare.$username.keys |%{
            $toUpdate = $_;
            write-warning "updating $toUpdate for $username"
            switch($toUpdate)
            {
                "local"{
                    write-warning "updating $username local flair to $highestcurrentFlair"
                    #invoke-sqlupdate -Query "UPDATE flair set trade_count = @newCount, updated = NOW() where userId = @userId" -Parameters @{newCount=$highestCurrentFlair;userId=$(if($username -eq $parentUserName){$parentUserId}else{$confirmingUserId})} -ConnectionName redditbot
                    invoke-sqlupdate -query "INSERT INTO flair (userId,trade_count,updated) VALUES (@userId, @newCount, NOW()) ON DUPLICATE KEY UPDATE trade_count = VALUES(trade_count), updated = NOW()" -Parameters @{newCount=$highestCurrentFlair;userId=$(if($username -eq $parentUserName){$parentUserId}else{$confirmingUserId})} -ConnectionName redditbot
                }
                default{

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
                    python3 ./set-userflair.py $toUpdate $username $Newflair
                }
            }
        }
    }
    write-warning "Writing Added! to $currentConfirmingMessageId"
    python3 ./new-redditmessage.py $currentConfirmingMessageId "Added!"
}