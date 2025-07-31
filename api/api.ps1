
import-module simplysql
import-module Pode

Start-PodeServer {
    . ./awsHelper.ps1


    $ss = ConvertTo-SecureString $ENV:MYSQL_PASSWORD -AsPlainText -Force
    $connectionName = "api"

    $dataAccessObject = @{
        "allUsers" = "select redditId, trade_count from users join flair on users.id = flair.userid";
        "tradesByUsername" = "select updated,trade_count,emojis,redditId from flair join users on flair.userid = users.id where users.redditId = @redditUsername";
        "tradePartners" = @"
            WITH
            confirmations as (
            SELECT messages.redditId as MessageId,redditParentId as ParentMessageId,LOWER(body) LIKE '%confirmed%',body,created, users.redditId as Username FROM messages
            JOIN users on messages.userId = users.id
            where tradeThreadId = 2 and LOWER(body) LIKE '%confirmed%' and (redditParentId is not null and redditParentId <> '')),
            top_level_comments as (
            SELECT messages.redditId as MessageId,redditParentId as ParentMessageId,body,created, users.id as userID ,users.redditId as Username
            FROM messages
            JOIN users on messages.userId = users.id
            where tradeThreadId = 2 and (redditParentId is null or redditParentId = '')),
            trade_log as (
            select t.MessageId topLevelMessage, c.MessageId confirmingMessage, t.Username as commentingUser, c.Username as taggedUser, t.body, c.body as confirmation
            FROM confirmations c
            JOIN top_level_comments t on c.ParentMessageId = t.MessageId
            ),
            filterTable as (
            select * From trade_log
            where commentingUser <> taggedUser AND body LIKE CONCAT('%u/', taggedUser, '%')
            ),
            partner_pairs as (
            Select commentingUser as user, taggedUser as trade_partner
            from filterTable
            UNION
            select taggedUser as user, commentingUser as trade_partner
            from filterTable
            )
            SELECT user, JSON_ARRAYAGG(trade_partner) AS unique_trade_partners
            FROM partner_pairs
            where user = @username
            GROUP BY user

"@;
        "tradeHistory" = @"
            WITH
            confirmations as (
            SELECT messages.redditId as MessageId,redditParentId as ParentMessageId,LOWER(body) LIKE '%confirmed%',body,created, users.redditId as Username FROM messages
            JOIN users on messages.userId = users.id
            where tradeThreadId = 2 and LOWER(body) LIKE '%confirmed%' and (redditParentId is not null and redditParentId <> '')),
            top_level_comments as (
            SELECT messages.redditId as MessageId,redditParentId as ParentMessageId,body,created, users.id as userID ,users.redditId as Username
            FROM messages
            JOIN users on messages.userId = users.id
            where tradeThreadId = 2 and (redditParentId is null or redditParentId = '')),
            trade_log as (
            select t.MessageId as topLevelMessage, c.MessageId as confirmingMessage, t.Username as commentingUser, c.Username as taggedUser, t.body, c.body as confirmation
            FROM confirmations c
            JOIN top_level_comments t on c.ParentMessageId = t.MessageId
            where t.Username <> c.Username AND t.body LIKE CONCAT('%u/', c.Username, '%')
            )

            select m2.created, commentingUser, taggedUser, m2.body as trade, m1.body as confirmation, CONCAT((select url from tradethreads where id = m2.tradeThreadId),m2.redditId,"/") as link from trade_log 
            join messages m1 on trade_log.confirmingMessage = m1.redditId
            join messages m2 on trade_log.topLevelMessage = m2.redditId
            join tradethreads on m2.tradeThreadId = tradethreads.id
            where 
            commentingUser = @username or taggedUser = @username
"@
    }

    $tradesByUsernameQuery = $dataAccessObject.tradesByUsername
    $tradePartnersQuery = $dataAccessObject.tradePartners
    $allusersQuery = $dataAccessObject.allUsers
    $tradehistoryQuery = $dataAccessObject.tradeHistory

    Add-PodeEndpoint -Address localhost -Port 9054 -name api.tradeflair.bitbinder.net -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeHtmlResponse -Value @"
        <html>
        <head>
        <body>
        <h1>Api.TradeFlair.BitBinder.Net</h1>
        <p>try your username in the following link
        <p>https://api.tradeflair.bitbinder.net/api/yourusername
"@
    }

    Add-PodeRoute -Method get -Path '/api/user/:username' -ScriptBlock {
        Open-mySqlConnection -ConnectionName $using:connectionName -Server $ENV:MYSQL_SERVER -Port $ENV:MYSQL_SERVER_PORT -Database redditbot -credential $(New-Object -TypeName 'System.Management.Automation.PsCredential' -ArgumentList $ENV:MYSQL_USER,$using:ss)
        $username = $WebEvent.Parameters['username']
        Set-SqlConnection -ConnectionName $using:connectionName
        $query = $using:tradesByUsernameQuery
        $dt = Invoke-SqlQuery -Query $query -Parameters @{redditUsername=$username} -ConnectionName $using:connectionName
        $jsresponse = $dt | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors | ConvertTo-Json
        write-podejsonresponse -value $jsresponse
        close-sqlconnection -ConnectionName $using:connectionName
    }

    Add-PodeRoute -Method Get -Path '/api/users' -ScriptBlock {
        Open-mySqlConnection -ConnectionName $using:connectionName -Server $ENV:MYSQL_SERVER -Port $ENV:MYSQL_SERVER_PORT -Database redditbot -credential $(New-Object -TypeName 'System.Management.Automation.PsCredential' -ArgumentList $ENV:MYSQL_USER,$using:ss)
        Set-SqlConnection -ConnectionName $using:connectionName
        $dt = Invoke-SqlQuery -Query $using:allusersquery -ConnectionName $using:connectionName
        $jsresponse = $dt | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors | ConvertTo-Json
        write-podejsonresponse -value $jsresponse
        close-sqlconnection -ConnectionName $using:connectionName
    }

    Add-PodeRoute -Method Get -Path '/api/tradepartners/:username' -ScriptBlock {
        Open-mySqlConnection -ConnectionName $using:connectionName -Server $ENV:MYSQL_SERVER -Port $ENV:MYSQL_SERVER_PORT -Database redditbot -credential $(New-Object -TypeName 'System.Management.Automation.PsCredential' -ArgumentList $ENV:MYSQL_USER,$using:ss)
        $username = $WebEvent.Parameters['username']
        Set-SqlConnection -ConnectionName $using:connectionName
        $dt = Invoke-SqlQuery -Query $using:tradePartnersQuery -Parameters @{username=$username} -ConnectionName $using:connectionName
        $jsresponse = $dt | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors | ConvertTo-Json
        write-podejsonresponse -value $jsresponse
        close-sqlconnection -ConnectionName $using:connectionName
    }

    Add-Poderoute -method Get -path '/api/tradehistory/:username' -scriptblock {
        Open-mySqlConnection -ConnectionName $using:connectionName -Server $ENV:MYSQL_SERVER -Port $ENV:MYSQL_SERVER_PORT -Database redditbot -credential $(New-Object -TypeName 'System.Management.Automation.PsCredential' -ArgumentList $ENV:MYSQL_USER,$using:ss)
        $username = $WebEvent.Parameters['username']
        Set-SqlConnection -ConnectionName $using:connectionName
        $query = $using:tradehistoryQuery
        $dt = Invoke-SqlQuery -Query $query -parameters @{username=$username} -ConnectionName $using:connectionName
        $jsresponse = $dt | Select-Object * -ExcludeProperty ItemArray, Table, RowError, RowState, HasErrors | ConvertTo-Json
        write-podejsonresponse -value $jsresponse
        close-sqlconnection -ConnectionName $using:connectionName
    }
}
 