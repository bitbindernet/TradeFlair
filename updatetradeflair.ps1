import-module simplysql
. ./awsHelper.ps1
$processRedditupdates = $false


$ss = ConvertTo-SecureString $ENV:MYSQL_PASSWORD -AsPlainText -Force
Open-mySqlConnection -ConnectionName redditbot -Server $ENV:MYSQL_SERVER -Port $ENV:MYSQL_SERVER_PORT -Database redditbot -credential $(New-Object -TypeName 'System.Management.Automation.PsCredential' -ArgumentList $ENV:MYSQL_USER,$ss)

$threads = Invoke-SqlQuery -Query "select * from tradethreads where active = 1" -ConnectionName redditbot
#$threads = Invoke-SqlQuery -Query "select * from tradethreads where id = 4" -ConnectionName redditbot
$mostRecentFlairUpdate = invoke-sqlquery -query "Select updated from flair order by updated desc limit 1" -ConnectionName redditbot
$messagesSinceMostRecentFlairUpdate = invoke-sqlquery -query "select * from messages where tradeThreadId in (select id from tradethreads where active = 1) and created > @mostRecentFlairUpdate" -Parameters @{mostrecentFlairUpdate=$mostRecentFlairUpdate.updated} -ConnectionName redditbot

$messagesToProcess = $messagesSinceMostRecentFlairUpdate.Clone();
#remove Added
$messagesSinceMostRecentFlairUpdate | where {$_.body -match "added" -and $_.redditParentId} |%{
    $currentMessage = $_
    $currentMessageId = $currentMessage.redditId
    $parentMessageId = $_.redditParentId
    $parentMessage = $messagesToProcess | ?{$_.redditId -eq $parentMessageId}
    $parentOfParentId = $parentMessage.redditParentId
    $parentOfParentMessage = $messagesToProcess | ?{$_.redditId -eq $parentOfParentId}
    write-warning "removing added message Chain`r`n $($currentMessageId) $($parentMessageId) $($parentOfParentId)"
    #$messagesToProcess = $messagesToProcess | where-object {$_ -ne $currentMessage }
    #$messagesToProcess = $messagesToProcess | where-object {$_.redditId -ne $currentMessage.redditParentId} 
    #$messagesToProcess = $messagesToProcess | where-object {$_.redditId -ne $($_.redditId -eq $currentMessage.redditParentId; $_.redditParentId)}
    $messagesToProcess = $messagesToProcess | where-object {$_.redditId -ne $currentMessageId}
    $messagesToProcess = $messagesToProcess | where-object {$_.redditId -ne $ParentMessageId} 
    $messagesToProcess = $messagesToProcess | where-object {$_.redditId -ne $parentOfParentId}
}

#find Confirmations
$confirmations = @();
$messagesToProcess | where {$_.body -match "confirm" -and $_.redditParentId}  | %{
    $confirmingMessage = $_;
    $parentMessage = $messagesToProcess | ?{$_.redditId -eq $confirmingMessage.redditParentId}
    $subreddit=$($threads |?{$_.id -eq $parentMessage.tradeThreadId}).subreddit
    #ensure tagging user isn't tagged user
    if($confirmingmessage.userId -ne $parentMessage.userId){
        #$parentMessage.body
        #write-host "$($parentMessage.body) --> confirmedBy --> $($confirmingMessage.body)"
        #write-host "ParentUserid: $($parentMessage.userid) traded with: $($confirmingMessage.userId)"
        $parentUserName = $(Invoke-SqlQuery -query "select redditId from users where id = @userId" -Parameters @{userId = $parentMessage.userId} -ConnectionName redditbot | select-object -ExpandProperty redditId)
        $confirmingUserName = $(Invoke-SqlQuery -query "select redditId from users where id = @userId" -Parameters @{userId = $confirmingMessage.userId} -ConnectionName redditbot | select-object -ExpandProperty redditId)
        $confirmingMessagesReplies = python3 ./Get-Replies.py --message-ids $confirmingMessage.redditId --stdout --json | convertfrom-json
        if($confirmingMessagesReplies){
            if($confirmingMessagesReplies.body.contains("Added")){
                write-warning "Skipping message with an already added reply: $($confirmingMessage.redditId)"
                continue; 
            }
        }
        if($parentMessage.body -match $(Invoke-SqlQuery -query "select redditId from users where id = @userId" -Parameters @{userId = $confirmingMessage.userId} -ConnectionName redditbot | select-object -ExpandProperty redditId)){
            
            #write-host "ParentUserid: $($parentMessage.userid) traded with: $($confirmingMessage.userId)"
            #write-host "-->`r`n`t$($parentMessage.body)`r`nconfirmedBy`r`n-->`r`n`t$($confirmingMessage.body)"
            #todo:
            
            $currentParentUserFlairOnSubreddit =     Parse-FlairText $(python3 ./Get-userFlairBySubreddit.py $subreddit $parentUserName | convertfrom-json).$parentUsername
            $currentConfirmingUserFlairOnSubreddit = Parse-FlairText $(python3 ./Get-userflairbysubreddit.py $subreddit $confirmingUserName | convertfrom-json).$confirmingUserName
            #1. increment trade_count in flair table
            #write-host "$parentUserName :"
            #$currentParentUserFlaironSubreddit
            #write-host "$confirmingUserName :"
            #$currentConfirmingUserFlairOnSubreddit
            #2. Update Userflairs
            $newParentUserFlair = Invoke-SqlQuery -Query "select redditId,trade_count,emojis from flair join users on flair.userId = users.id where userId = @userId" -Parameters @{userId=$parentMessage.userId} -ConnectionName redditbot;
            $newconfirmingUserFlair = Invoke-SqlQuery -Query "select redditId,trade_count,emojis from flair join users on flair.userId = users.id where userId = @userId" -Parameters @{userId=$ConfirmingMessage.userId} -ConnectionName redditbot;
            #2.1 Check flair on subreddit (make sure we don't overrwite custom emojis, make sure not banned etc.)
            #"$parentUserName trades: $($newParentUserFlair.trade_count) should equal $($currentParentUserFlairOnSubreddit.trades)"
            #"$confirmingUserName trades: $($newconfirmingUserFlair.trade_count) should equal $($currentConfirmingUserFlairOnSubreddit.trades)"

            $confirmations += @{
                "ParentUserName"= $parentUserName;
                "ParentUserId"= $parentMessage.userId;
                "ParentCurrentRedditTradeFlair"= $currentParentUserFlairOnSubreddit.trades;
                "ParentCurrentSubredditUserEmojis" = $currentParentUserFlairOnSubreddit.Emojis
                "ParentLocalFlair"= $newParentUserFlair.trade_count;
                "ParentTradeBody" = $parentMessage.body
                "ConfirmingUserName"= $confirmingUserName;
                "ConfirmingUserId" = $confirmingMessage.userId;
                "ConfirmingCurrentRedditTradeFlair" = $currentConfirmingUserFlairOnSubreddit.trades;
                "ConfirmingCurrentSubredditUserEmojis" = $currentConfirmingUserFlairOnSubreddit.emojis
                "ConfirmingLocalFLair" = $newconfirmingUserFlair.trade_count;
                "ConfirmingMessageBody" = $confirmingMessage.body
            }

            if($processRedditupdates)
            {
                
                #trade flair count is in sync
                if(($newParentUserFlair.trade_count -eq $currentParentUserFlairOnSubreddit.trades) -and ($newconfirmingUserFlair.trade_count -eq $currentConfirmingUserFlairOnSubreddit.trades)){
                    Invoke-SqlUpdate -Query "UPDATE flair SET trade_count = trade_count + 1 WHERE userid in (@parentUser,@confirmingUser)" -Parameters @{parentUser=$parentMessage.userId;confirmingUser=$confirmingmessage.userId} -ConnectionName redditbot
                    python3 ./Set-UserFlair.py $subreddit $newParentUserFlair.redditId "Trades: $($($currentParentUserFlairOnSubreddit.trades)+1) :$($currentParentUserFlairOnSubreddit.Emojis -join "::"):"
                    python3 ./Set-UserFlair.py $subreddit $newConfirmingUserFlair.redditId "Trades: $($($currentConfirmingUserFlairOnSubreddit.trades)+1) :$($currentConfirmingUserFlairOnSubreddit.Emojis -join "::"):"
                    #2. post added to confirming message
                    
                }
                #Sub reddit flair is higher than local flair
                #if(($newParentUserFlair.trade_count -lt $currentParentUserFlairOnSubreddit.trades)){
                #    Invoke-SqlUpdate -Query "UPDATE flair SET trade_count = @CurrentTradeCount WHERE userid = @parentUser" -Parameters @{CurrentTradeCount=$currentParentUserFlairOnSubreddit.trades;parentUser=$parentMessage.userId} -ConnectionName redditbot
                #    python3 ./Set-UserFlair.py $subreddit $newParentUserFlair.redditId "Trades: $($($currentParentUserFlairOnSubreddit.trades)+1) :$($currentParentUserFlairOnSubreddit.Emojis -join "::"):"
                #    #2. post added to confirming message
                #   
                #}
                #if(($newconfirmingUserFlair.trade_count -lt $currentConfirmingUserFlairOnSubreddit.trades)){
                #    Invoke-SqlUpdate -Query "UPDATE flair SET trade_count = @CurrentTradeCount WHERE userid = @ConfirmingUser" -Parameters @{CurrentTradeCount=$currentConfirmingUserFlairOnSubreddit.trades;ConfirmingUser=$ConfirmingMessage.userId} -ConnectionName redditbot
                #    python3 ./Set-UserFlair.py $subreddit $newConfirmingUserFlair.redditId "Trades: $($($currentConfirmingUserFlairOnSubreddit.trades)+1) :$($currentConfirmingUserFlairOnSubreddit.Emojis -join "::"):"
                #    #2. post added to confirming message
                #    
                #}
                python3 ./New-RedditMessage.py $confirmingMessage.redditId "Added!"
                #if($newParentUserFlair.trade_count -eq $currentParentUserFlairOnSubreddit.trades)
                #{
                #    #Can update parent user trade count by 1
                #    Invoke-sqlupdate -query "UPDATE flair SET trade_count = trade_count + 1 WHERE userid = @parentUser" -Parameters @{parentUser=$parentMessage.userId} -ConnectionName redditbot
                #}
                #if($newconfirmingUserFlair.trade_count -eq $currentConfirmingUserFlairOnSubreddit.trades)
                #{
                #    #Can update parent user trade count by 1
                #    Invoke-sqlupdate -query "UPDATE flair SET trade_count = trade_count + 1 WHERE userid = @ConfirmingUser" -Parameters @{ConfirmingUser=$ConfirmingMessage.userId} -ConnectionName redditbot
                #}
            }
        }
    }
}

