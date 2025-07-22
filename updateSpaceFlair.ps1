import-module simplysql
. ./awsHelper.ps1
$processRedditupdates = $false


$ss = ConvertTo-SecureString $ENV:MYSQL_PASSWORD -AsPlainText -Force
Open-mySqlConnection -ConnectionName redditbot -Server $ENV:MYSQL_SERVER -Port $ENV:MYSQL_SERVER_PORT -Database redditbot -credential $(New-Object -TypeName 'System.Management.Automation.PsCredential' -ArgumentList $ENV:MYSQL_USER,$ss)

$threads = Invoke-SqlQuery -Query "select * from tradethreads where id = 4" -ConnectionName redditbot
$messagesFromSpace = invoke-sqlquery -query "select * from messages where tradeThreadId = 4" -ConnectionName redditbot

$messagesToProcess = $messagesFromSpace.Clone()
$messagesFromSpace | where {$_.body -match "confirm" -and $_.redditParentId} |%{
    $currentConfirmingMessage = $_;
    $currentConfirmingMessageId = $currentConfirmingMessage.redditId;
    $currentConfirmingMessageParentMessageId = $currentConfirmingMessage.redditParentId;
    $currentParentMessage = $messagesToProcess | ?{$_.redditId -eq $currentConfirmingMessageParentMessageId};
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
    
    $confirmingMessagesReplies = python3 ./Get-Replies.py --message-ids $currentConfirmingMessageId --stdout --json | convertfrom-json
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
        $parentUserName = @{"local"=@{"Trades"=$parentUserTradeCount}};
        $confirmingUsername = @{"local"=@{"Trades"=$ConfirmingUserTradeCount}}
    }
    $threads | %{
        $currentThread = $_;
        write-warning "Downloading current flair for $parentUsername on $($currentThread.Subreddit)"
        $currentParentUserFlairOnSubreddit     = Parse-FlairText $(python3 ./Get-userFlairBySubreddit.py $currentThread.subreddit $parentUserName | convertfrom-json).$parentUsername
        write-warning "Downloading current flair for $confirmingUserName on $($currentThread.Subreddit)"
        $currentConfirmingUserFlairOnSubreddit = Parse-FlairText $(python3 ./Get-userflairbysubreddit.py $currentThread.subreddit $confirmingUserName | convertfrom-json).$confirmingUserName
        $tradeFlaircompare.$parentUserName.add($currentThread.subreddit.ToString(),$currentParentUserFlairOnSubreddit)
        #$tradeFlaircompare.$parentUserName.add($($currentThread.subreddit),$currentParentUserFlairOnSubreddit.Emojis)
        $tradeFlairCompare.$confirmingUserName.add($currentThread.subreddit.ToString(),$currentConfirmingUserFlairOnSubreddit)
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
                    invoke-sqlupdate -Query "UPDATE flair set trade_count = @newCount where userId = @userId" -Parameters @{newCount=$highestCurrentFlair;userId=$(if($username -eq $parentUserName){$parentUserId}else{$confirmingUserId})} -ConnectionName redditbot
                }
                default{
                    if($tradeFlairCompare.$username.$toUpdate.Emojis){
                        write-warning "User $username, has emojis in $toTupdate"
                        $Newflair = "Trades: $($highestCurrentFlair) :$($tradeFlairCompare.$username.$toUpdate.Emojis -join ":"):"
                    }
                    else
                    {
                        write-warning "User $username, does not have emojis in $toTupdate"
                        $NewFlair = "Trades: $($highestCurrentFlair)"
                    }
                    write-warning "Setting $toUpdate --> $username --> $Newflair"
                    python3 ./set-userflair.py $toUpdate $username $Newflair
                }
            }
        }
    }
    write-warning "Writing Added! to $currentConfirmingMessageId"
    python3 ./New-redditMessage.py $currentConfirmingMessageId "Added!"
}