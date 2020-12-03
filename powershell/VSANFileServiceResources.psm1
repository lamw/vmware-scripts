Function Get-VSANFSResources {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function demonstrates the use of vSAN Management API to retrieve
        the resources allocated to both the vSAN File Server backend and vSAN File Service VMs
    .PARAMETER Cluster
        The name of a vSAN Cluster
    .EXAMPLE
        Get-VSANFSResources -Cluster OCTO-Cluster
#>
    param(
        [Parameter(Mandatory=$true)][String]$Cluster
    )

    # Scope query within vSAN/vSphere Cluster
    $clusterView = Get-Cluster -Name $Cluster -ErrorAction SilentlyContinue
    if($clusterView) {
        $clusterMoref = $clusterView.ExtensionData.MoRef
    } else {
        Write-Host -ForegroundColor Red "Unable to find vSAN Cluster $cluster ..."
        break
    }

    $vsanConfigSystem = Get-VsanView -Id VsanVcClusterConfigSystem-vsan-cluster-config-system
    $results = $vsanConfigSystem.VsanClusterGetConfig($clusterMoref)
    $results.FileServiceConfig | select Enabled, FileServerMemoryMB, FileServerCPUMhz, FsvmMemoryMB, FsvmCPU
}

Function Set-VSANFSResources {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function demonstrates the use of vSAN Management API to enable vSAN File Services
        with custom resource (CPU/MEM) settings for both the vSAN File Server backend and vSAN File Service VMs
    .PARAMETER Cluster
        The name of a vSAN Cluster
    .PARAMETER fsReservedCPU
        Reserved CPU (Mhz) for vSAN File Server (default 0)
    .PARAMETER fsReservedMem
        Reserved Memory (MB) for vSAN File Server (default 960)
    .PARAMETER fsVMReservedCPU
        Reserved CPU Cores for vSAN File Services VM (default 2)
    .PARAMETER fsVMReservedMem
        Reserved Memory (MB) for vSAN File Services VM (default 2048)
    .EXAMPLE
        Set-VSANFSResources -Cluster OCTO-Cluster -Network VM51-DPortGroup -fsVMReservedMem 8096
    .EXAMPLE
        Set-VSANFSResources -Cluster OCTO-Cluster -Network VM51-DPortGroup  -fsReservedCPU 100 -fsReservedMem 1024 -fsVMReservedCPU 4 -fsVMReservedMem 10240
#>
    param(
        [Parameter(Mandatory=$true)][String]$Cluster,
        [Parameter(Mandatory=$true)][String]$Network,
        [Parameter(Mandatory=$false)][String]$fsReservedCPU,
        [Parameter(Mandatory=$false)][String]$fsReservedMem,
        [Parameter(Mandatory=$false)][String]$fsVMReservedCPU,
        [Parameter(Mandatory=$false)][String]$fsVMReservedMem
    )

    # Scope query within vSAN/vSphere Cluster
    $clusterView = Get-Cluster -Name $Cluster -ErrorAction SilentlyContinue
    if($clusterView) {
        $clusterMoref = $clusterView.ExtensionData.MoRef
    } else {
        Write-Host -ForegroundColor Red "Unable to find vSAN Cluster $cluster ..."
        break
    }

    $networkView = Get-VirtualNetwork -Name $Network -ErrorAction SilentlyContinue
    if($networkView) {
        $networkMoref = $networkView.ExtensionData.MoRef
    } else {
        Write-Host -ForegroundColor Red "Unable to find vSphere Network $Network ..."
        break
    }

    # https://vdc-download.vmware.com/vmwb-repository/dcr-public/9ab58fbf-b389-4e15-bfd4-a915910be724/7872dcb2-3287-40e1-ba00-71071d0e19ff/vim.vsan.FileServiceConfig.html
    $vsanFSSpec = New-Object VMware.Vsan.Views.VsanFileServiceConfig
    $vsanFSSpec.Enabled = $true
    $vsanFSSpec.Network = $networkMoref

    if($fsReservedCPU) {
        $vsanFSSpec.fileServerCPUMhz = $fsReservedCPU
    }

    if($fsReservedMem) {
        $vsanFSSpec.fileServerMemoryMB = $fsReservedMem
    }

    if($fsVMReservedCPU) {
        $vsanFSSpec.fsvmCPU = $fsVMReservedCPU
    }

    if($fsVMReservedMem) {
        $vsanFSSpec.fsvmMemoryMB = $fsVMReservedMem
    }

    $spec = New-Object VMware.Vsan.Views.VimVsanReconfigSpec
    $spec.modify = $true
    $spec.FileServiceConfig = $vsanFSSpec

    Write-Host -ForegroundColor cyan "Enabling and applying custom resource settings to vSAN File Services ... "
    $vsanConfigSystem = Get-VsanView -Id VsanVcClusterConfigSystem-vsan-cluster-config-system
    $task = $vsanConfigSystem.VsanClusterReconfig($clusterMoref,$spec)
    $task1 = Get-Task -Id ("Task-$($task.value)")
    $task1 | Wait-Task
}
