. .\awsHelper.ps1
. .\functions.ps1
$ss = ConvertTo-SecureString $ENV:MYSQL_PASSWORD -AsPlainText -Force
Open-mySqlConnection -ConnectionName redditbot -Server $ENV:MYSQL_SERVER -Port $ENV:MYSQL_SERVER_PORT -Database redditbot -credential $(New-Object -TypeName 'System.Management.Automation.PsCredential' -ArgumentList $ENV:MYSQL_USER,$ss)

# Your JSON flair data (replace with your file path)
$jsonPath = ".\tradeFlairPointInTime\7-20-2025.json"
$flairData = Get-Content $jsonPath | ConvertFrom-Json


# Parsing function
function Parse-Flair {
    param ($flairText)

    # Extract trade count
    if ($flairText -match 'Trades\s*:?\s*(\d+)') {
        $tradeCount = [int]$matches[1]
    } else {
        $tradeCount = 0
    }

    # Correct emoji extraction
    $emojis = @()
    $matches = [regex]::Matches($flairText, ':(\w+?):')
    foreach ($match in $matches) {
        $emojis += $match.Groups[1].Value
    }

    return @{
        TradeCount = $tradeCount
        Emojis     = $emojis
    }
}

# Today's date for 'updated' column
$today = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

foreach ($username in $flairData.PSObject.Properties.Name) {
    $flairText = $flairData.$username
    $parsed = Parse-Flair $flairText
    $emojiJson = ($parsed.Emojis | ConvertTo-Json -Compress)

    # Fetch user ID from the users table
    $userResult = Invoke-SqlQuery -Query @"
        SELECT id FROM users WHERE redditId = @redditId LIMIT 1;
"@ -Parameters @{ redditId = $username } -ConnectionName redditbot

    if ($userResult) {
        $userid = $userResult.id

        # Insert or update flair table
        Invoke-SqlUpdate -Query @"
            INSERT INTO flair (flaircol, updated, userid, trade_count, emojis)
            VALUES (
                @flaircol,
                @updated,
                @userid,
                @trade_count,
                @emojis
            )
            ON DUPLICATE KEY UPDATE
                updated = @updated,
                trade_count = @trade_count,
                emojis = @emojis;
"@ -Parameters @{
            flaircol    = $flairText   # Optional; original flair text
            updated     = $today
            userid      = $userid
            trade_count = $parsed.TradeCount
            emojis      = $emojiJson
        } -ConnectionName redditbot
    } else {
        Write-Warning "User '$username' not found in 'users' table."
    }
}

# Close MySQL connection
Close-SqlConnection
