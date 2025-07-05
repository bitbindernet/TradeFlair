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

function Parse-FlairText {
    param (
        [parameter(position=0,valuefrompipeline=$true)][string]$FlairText
    )

    $result = @{
        Trades = 0
        Emojis = @()
    }

    if (-not $FlairText) {
        return $result
    }

    # Parse trade count (supports decimal numbers like 69.420)
    $tradeMatch = [regex]::Match($FlairText, 'Trades:\s*([\d.]+)')
    if ($tradeMatch.Success) {
        $result["Trades"] = [float]$tradeMatch.Groups[1].Value
    }

    # Parse emojis
    $emojiMatches = [regex]::Matches($FlairText, ':(\w+?):')
    $result["Emojis"] = $emojiMatches | ForEach-Object { $_.Groups[1].Value }

    return $result
}

function Out-Confirmations
{
    param($confirmations);
    $confirmations | ForEach-Object {
    [PSCustomObject]@{
        ParentUserName                    = $_.ParentUserName
        ParentUserId                      = $_.ParentUserId
        ParentCurrentRedditTradeFlair     = $_.ParentCurrentRedditTradeFlair
        ParentLocalFlair                  = $_.ParentLocalFlair
        ParentTradeBody                   = $_.ParentTradeBody
        ConfirmingUserName                = $_.ConfirmingUserName
        ConfirmingUserId                  = $_.ConfirmingUserId
        ConfirmingCurrentRedditTradeFlair = $_.ConfirmingCurrentRedditTradeFlair
        ConfirmingLocalFlair              = $_.ConfirmingLocalFlair
        ConfirmingMessageBody             = $_.ConfirmingMessageBody
    }
} | Out-GridView -Title "Trade Confirmations" -OutputMode Multiple
}
