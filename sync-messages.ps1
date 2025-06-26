param(
    $messagesFile = "./messages.json"
)
Import-Module SimplySql;

$messages = gc -raw $messagesFile

$messagesData = ConvertFRom-json -depth 100 $messages

if(-not $(Get-SqlConnection -ConnectionName redditbot)){
    $ss = ConvertTo-SecureString $ENV:MYSQL_PASSWORD -AsPlainText -Force
    Open-mySqlConnection -ConnectionName redditbot -Server $ENV:MYSQL_SERVER -Port $ENV:MYSQL_SERVER_PORT -Database redditbot -credential $(New-Object -TypeName 'System.Management.Automation.PsCredential' -ArgumentList $ENV:MYSQL_USER,$ss)
}

$tradeThreadId = invoke-sqlquery -Query "select id from tradethreads where redditId = @id" -Parameters @{id=$messagesdata.thread_id} -ConnectionName redditbot
# Insert user
$insertUser =  @'
INSERT INTO users (redditId, jsondata)
VALUES (@redditId, @json)
ON DUPLICATE KEY UPDATE jsondata = VALUES(jsondata);
'@

# Insert message
$InsertMessage = @'
INSERT INTO messages
       (json, redditId, redditParentId, userId, body, created, tradeThreadId)
VALUES (@json, @redditId, @redditParentId, @userId, @body, @created, @tradeThreadId)
ON DUPLICATE KEY UPDATE body = VALUES(body);
'@

#$InsertThread = @'
#INSERT INTO tradethreads (redditId, url, name, json)
#VALUES (@redditId, @url, @name, @json)
#ON DUPLICATE KEY UPDATE
#        url  = VALUES(url),
#        name = VALUES(name),
#        json = VALUES(json);
#'@

function Add-RedditMessage {
    param (
        [Parameter(Mandatory)]
        $MessageObj,

        [parameter()][string] $ParentId = $null,
        [parameter()][string] $tradeThreadId
    )

    # ---------- 1.  Insert / update the user ----------
    $userParams = @{
        redditId = $MessageObj.author
        json     = '{}' #empty for now
    }
    Invoke-SqlUpdate -ConnectionName redditbot -Query $insertUser -Parameters $userParams

    # ---------- 2.  Grab the user’s PK ----------
    $userPk = Invoke-SqlScalar -Query 'SELECT id FROM users WHERE redditId = @rid' -Parameters @{ rid = $MessageObj.author } -ConnectionName redditbot

    # ---------- 2.  Insert / update the message ----------
    $msgParams = @{
        json           = ($MessageObj | ConvertTo-Json -Depth 100)
        redditId       = $MessageObj.id
        redditParentId = $ParentId
        userId         = $userPk
        body           = $MessageObj.body
        created        = ([DateTime]::UnixEpoch).AddSeconds($MessageObj.created_utc)
        tradeThreadId  = $tradeThreadId
    }
    Invoke-SqlUpdate -ConnectionName redditbot -Query $InsertMessage -Parameters $msgParams

    # ---------- 3.  Recurse into replies ----------
    foreach ($reply in $MessageObj.replies) {
        Add-RedditMessage -MessageObj $reply -ParentId $MessageObj.id -tradeThreadId $tradeThreadId
    }
}

$messagesData.comments | foreach-object {Add-RedditMessage -messageObj $_ -ParentId $null -tradeThreadId "$($tradeThreadId.id)"}