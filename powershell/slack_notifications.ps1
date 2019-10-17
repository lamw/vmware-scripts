Function Set-SlackNotification {
    <#
        .DESCRIPTION Enable or Disable @channel and @here notifications for Slack Channel
        .NOTES  Author:  William Lam
        .NOTES  Site:    www.virtuallyghetto.com
        .NOTES  Reference: http://www.virtuallyghetto.com/2019/10/automate-disabling-channel-here-notifications-using-private-slack-api.html
        .PARAMETER SlackAccessToken
            This is your OAuth Access Token that you will need to either provide or generate as part of the OAuth login workflow
        .PARAMETER SlackBrowserAccessToken
            This is the OAuth Access Token which will be retrieved from the browser and is scoped to access the private Slack API
        .PARAMETER SlackBrowserSessionCookie
            This is the internal Slack cookie that is required to be able to access the private Slack API
        .PARAMETER Operation
            Enable or Disable
        .PARAMETER ExcludeChannels
            List of Slack Channels to ignore
        .EXAMPLE
            $SlackAccessToken = "xxx"
            $SlackBrowserAccessToken = "xxx"
            $SlackBrowserSessionCookie = "xxx"
            $ExcludeChannels = @(
            "channel1",
            "channel2",
            "channel3"
            )

            Set-SlackNotification -SlackAccessToken $SlackAccessToken -SlackBrowserAccessToken $SlackBrowserAccessToken -SlackBrowserSessionCookie $SlackBrowserSessionCookie -Operation Disable -ExcludeChannels $ExcludeChannels
    #>
    param(
        [Parameter(Mandatory=$true)][string]$SlackAccessToken,
        [Parameter(Mandatory=$true)][string]$SlackBrowserAccessToken,
        [Parameter(Mandatory=$true)][string]$SlackBrowserSessionCookie,
        [Parameter(Mandatory=$true)][ValidateSet("Enable","Disable")][string]$Operation,
        [Parameter(Mandatory=$false)][string[]]$ExcludeChannels
    )

    $headers = @{
        "Accept" = "application/x-www-form-urlencoded";
    }

    # Retrieve all Slack channels user is part of
    $conversation_results = Invoke-WebRequest -Uri "https://slack.com/api/users.conversations" -Method GET -Headers $headers -Body @{"token"=$SlackAccessToken;"limit"=1000;"exclude_archived"="true";"types"="public_channel,private_channel";}
    $slack_channels = ($conversation_results.Content|ConvertFrom-Json).channels | Select id,name

    # Determine the notification operation
    if($Operation -eq "Enable") {
        Write-Host "Enabling @channel and @here notification for the following channels"
        $notification_value = "false"
    } else {
        Write-Host "Disabling @channel and @here notification for the following channels"
        $notification_value = "true"
    }

    # Construct the required cookie to call Private Slack API
    $websession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $cookie = New-Object System.Net.Cookie
    $cookie.Name = "d"
    $cookie.Value = $SlackBrowserSessionCookie
    $cookie.Domain = "slack.com"
    $websession.Cookies.Add($cookie)

    foreach ($slack_channel in $slack_channels) {
        if( ($ExcludeChannels.toLower()) -NotContains ($slack_channel.name).toLower() ) {

            $body = @{
                "token" = $SlackBrowserAccessToken;
                "name" = "suppress_at_channel";
                "value" = $notification_value;
                "channel_id" = $($slack_channel.id);
                "global" = "false";
                "sync" = "false";
            }

            Write-Host "`tUpdating $($slack_channel.name) channel ..."
            try {
                $requests = Invoke-WebRequest -Uri "https://vmware.slack.com/api/users.prefs.setNotifications" -Method Post -Headers $headers -Body $body -WebSession $websession
                if(-not ($requests.Content|ConvertFrom-Json).ok) {
                    Write-Error "Failed to update $($slack_channel.name) channel ($($slack_channel.id))"
                    Write-Error "`n($requests.Content)`n"
                    break
                }
            } catch {
                Write-Error "Error in updating $($slack_channel.name) channel ($($slack_channel.id))"
                Write-Error "`n($_.Exception.Message)`n"
                break
            }
        }
    }
    Write-Host "Successfully $($Operation)d @channel and @here notification preferences for $($slack_channels.count) Slack Channels!"
}
