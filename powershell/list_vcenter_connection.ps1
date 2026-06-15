# Author: William Lam
# Description: List vCenter Connection Utilizations supported with VCF 9.1

$connectionService = Get-CisService "com.vmware.vcenter.utilization.connections"
$connection = $connectionService.list($null,$null).servers

Write-Host -ForegroundColor Cyan "`nConnection Limit: $($connection.connection_limit)"
Write-Host -ForegroundColor Cyan "Connections: $($connection.total_connections)`n"

$ports = $connection.ports
foreach($port in $ports) {
    if($port.open_connections -gt 0) {
        Write-Host -ForegroundColor Magenta "Type: $(${port}.name)"
        Write-Host -ForegroundColor Magenta "Port: $(${port}.port)"
        Write-Host -ForegroundColor Magenta "Connections: $(${port}.open_connections)"

        $peers = $port.peers

        $results = @()
        foreach ($peer in $peers | Sort-Object -Property Address) {
            $tmp = [pscustomobject] @{
                Address = $peer.Address
                Port = $peer.Port
                State = $peer.tcp_state
            }

            $results+=$tmp
        }

        $results
    }
}