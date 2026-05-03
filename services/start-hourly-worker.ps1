Set-Location /home/redditbot/Projects/TradeFlair

. ./venv/bin/Activate.ps1

Write-Warning "Starting TradeFlair hourly worker at $(Get-Date)"

while ($true) {
    $start = Get-Date

    try {
        Write-Warning "Starting hourly sync at $start"

        . ./runsync.ps1
        . ./updateallactive.ps1

        $end = Get-Date
        $duration = New-TimeSpan -Start $start -End $end

        Write-Warning "Hourly sync completed. Started: $start Ended: $end Duration: $duration"
    }
    catch {
        $end = Get-Date
        $duration = New-TimeSpan -Start $start -End $end

        Write-Error "Hourly sync failed. Started: $start Ended: $end Duration: $duration"
        Write-Error $_
    }

    Start-Sleep -Seconds 3600
}