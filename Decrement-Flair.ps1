param(
    [Parameter(Mandatory = $true)]
    [string]$UserName
)

. .\awsHelper.ps1
$ss = ConvertTo-SecureString $ENV:MYSQL_PASSWORD -AsPlainText -Force
Open-mySqlConnection -ConnectionName redditbot -Server $ENV:MYSQL_SERVER -Port $ENV:MYSQL_SERVER_PORT -Database redditbot -credential $(New-Object -TypeName 'System.Management.Automation.PsCredential' -ArgumentList $ENV:MYSQL_USER,$ss)

$threads = Invoke-SqlQuery -Query "select * from tradethreads where active = 1" -ConnectionName redditbot

$localUserFlair = Invoke-SqlQuery -query "select * from flair join users on flair.userid = users.id where users.redditId = @redditId" -Parameters @{redditId = $UserName} -ConnectionName redditbot
if ($localUserFlair -eq $null) {
    Write-Error "No flair found for user $UserName"
    exit 1
}   

$usersFlairOnThreads = @{}
$usersFlairOnThreads["local"] = @{"Trades"=$localUserFlair.trade_count}
foreach ($currentThread in $threads) {
    $threadFlair = Parse-FlairText $(python .\Get-UserFlairBySubreddit.py $currentThread.subreddit $UserName | ConvertFrom-Json).$UserName

    try{if ($threadFlair -ne $null) {
        $usersFlairOnThreads[$currentThread.subreddit] = $threadFlair
    } else {
        $usersFlairOnThreads[$currentThread.subreddit] = 0
    }}catch{
        Write-Error "Error retrieving flair for $UserName on subreddit $($currentThread.subreddit): $_"
        $usersFlairOnThreads[$currentThread.subreddit] = 0
    }
}

$highesttrade = $usersFlairOnThreads.values.Trades | sort-object -Descending | Select-Object -first 1;
$decrementflair = $highesttrade - 1;
if ($decrementflair -lt 0) {
    Write-Error "Cannot decrement flair below zero for user $UserName"
    exit 1
}
$updateQuery = "UPDATE flair SET trade_count = @tradeCount WHERE userid = (SELECT id FROM users WHERE redditId = @redditId)"
Invoke-SqlQuery -query $updateQuery -Parameters @{tradeCount = $decrementflair; redditId = $UserName} -ConnectionName redditbot

$threads | ForEach-Object {
    $currentThread = $_
        if($usersFlairOnThreads[$currentThread.subreddit].Emojis){
            write-warning "User $username, has emojis in $($currentThread.subreddit)"
            $Newflair = "Trades: $($decrementflair) :$($usersFlairOnThreads.($currentThread.subreddit).Emojis -join ":"):"
        }
        else
        {
            write-warning "User $username, does not have emojis in $toUpdate"
            $NewFlair = "Trades: $($decrementflair)"
        }
        python .\set-userflair.py $currentThread.subreddit $UserName $NewFlair 

}
