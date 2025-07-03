import-module simplysql
. ./awsHelper.ps1

$ss = ConvertTo-SecureString $ENV:MYSQL_PASSWORD -AsPlainText -Force
Open-mySqlConnection -ConnectionName redditbot -Server $ENV:MYSQL_SERVER -Port $ENV:MYSQL_SERVER_PORT -Database redditbot -credential $(New-Object -TypeName 'System.Management.Automation.PsCredential' -ArgumentList $ENV:MYSQL_USER,$ss)

$threads = Invoke-SqlQuery -Query "select * from tradethreads" -ConnectionName redditbot
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
    #ensure tagging user isn't tagged user
    if($confirmingmessage.userId -ne $parentMessage.userId){
            #$parentMessage.body
            #write-host "$($parentMessage.body) --> confirmedBy --> $($confirmingMessage.body)"
            #write-host "ParentUserid: $($parentMessage.userid) traded with: $($confirmingMessage.userId)"
            #$(Invoke-SqlQuery -query "select redditId from users where id = @userId" -Parameters @{userId = $confirmingMessage.userId} -ConnectionName redditbot | select-object -ExpandProperty redditId)
        if($parentMessage.body -match $(Invoke-SqlQuery -query "select redditId from users where id = @userId" -Parameters @{userId = $confirmingMessage.userId} -ConnectionName redditbot | select-object -ExpandProperty redditId)){
            write-host "$($parentMessage.body) --> confirmedBy --> $($confirmingMessage.body)"
            write-host "ParentUserid: $($parentMessage.userid) traded with: $($confirmingMessage.userId)"
            #todo:
            #1. increment trade_count in flair table
            Invoke-SqlUpdate -Query "UPDATE flair SET trade_count = trade_count + 1 WHERE userid in (@parentUser,@confirmingUser)" -Parameters @{parentUser=$parentMessage.userId;confirmingUser=$confirmingmessage.userId} -ConnectionName redditbot
            #2. Update Userflairs
            $newParentUserFlair = Invoke-SqlQuery -Query "select redditId,trade_count,emojis from flair join users on flair.userId = users.id where userId = @userId" -Parameters @{userId=$parentMessage.userId} -ConnectionName redditbot;
            $newconfirmingUserFlair = Invoke-SqlQuery -Query "select redditId,trade_count,emojis from flair join users on flair.userId = users.id where userId = @userId" -Parameters @{userId=$ConfirmingMessage.userId} -ConnectionName redditbot;
            python3 ./Set-UserFlair.py $($threads |?{$_.id -eq $parentMessage.tradeThreadId}).subreddit $newParentUserFlair.redditId "Trades: $($newParentUserFlair.trade_count) :$($($d.emojis | convertfrom-json)-join "::"):"
            #2. post added to confirming message
            python3 ./New-RedditMessage.py $confirmingMessage.redditId "Added!"
        }
    }
}