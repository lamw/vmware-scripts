<#
.SYNOPSIS
    Inventories a vCenter Server for vSphere Supervisor and vSphere Kubernetes Service (VKS)
    enablement, version and build information.

.DESCRIPTION
    Connects to a vCenter Server (via Connect-CisServer only - no SOAP/VI session needed) and
    reports on four things:
      1) vCenter Server Info                  -> com.vmware.appliance.system.version
      2) vSphere Supervisor Info               -> com.vmware.vcenter.namespace_management.supervisors.summary
                                                   + .topology (maps Supervisor name/ID to the
                                                   vSphere Cluster it runs on, via com.vmware.vcenter.cluster)
      3) vSphere Supervisor Services Info      -> com.vmware.vcenter.namespace_management.supervisors.supervisor_services
      4) vSphere Kubernetes Service workloads  -> TanzuKubernetesCluster / ClusterClass-based
                                                   `Cluster` objects inside each Supervisor's own
                                                   Kubernetes API (requires kubectl + kubectl-vsphere)

.PARAMETER VIServer
    FQDN or IP address of the vCenter Server to inventory.

.PARAMETER Credential
    PSCredential to authenticate to vCenter Server (and reused for the Supervisor Kubernetes API
    login in Section 4, if the Supervisor uses the same SSO domain). If not supplied, you will be
    prompted.

.PARAMETER SkipVKS
    Skip Section 4 (VKS guest cluster/workload inventory). Use this if kubectl/kubectl-vsphere
    are not available - you'll still get Sections 1-3.

.PARAMETER IgnoreCertificateErrors
    Ignore invalid/self-signed SSL certificate warnings for both PowerCLI and kubectl-vsphere.

.EXAMPLE
    ./Get-vSphereSupervisorAndVKSInventory.ps1 -VIServer vc01.vcf.lab

.EXAMPLE
    $vcCred = Get-Credential -Username "administrator@vsphere.local"
    ./Get-vSphereSupervisorAndVKSInventory.ps1 -VIServer vc01.vcf.lab -Credential $vcCred -IgnoreCertificateErrors
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$VIServer,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential,

    [switch]$SkipVKS,

    [switch]$IgnoreCertificateErrors
)

$ErrorActionPreference = 'Stop'

function Write-Section {
    param([string]$Title)
    Write-Host ''
    Write-Host ('=' * 80) -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ('=' * 80) -ForegroundColor Cyan
}

# Logs into a Supervisor's Kubernetes API via kubectl-vsphere and returns the kubectl context
# name to use for subsequent `kubectl ... --context` calls, or $null on failure.
#
# NOTE: `kubectl vsphere login` has no `--context` flag to name the context yourself - it names
# the context after the API server endpoint you logged into. So after a successful login we ask
# kubectl what the current context actually is, rather than assuming a name.
function Connect-SupervisorCluster {
    param(
        [string]$SupervisorName,
        [string]$ApiServerEndpoint,
        [System.Management.Automation.PSCredential]$Credential,
        [switch]$IgnoreCertificateErrors
    )

    $kubectlVsphereArgs = @(
        'vsphere', 'login',
        '--vsphere-username', $Credential.UserName,
        '--server', $ApiServerEndpoint
    )
    if ($IgnoreCertificateErrors) { $kubectlVsphereArgs += '--insecure-skip-tls-verify' }

    $env:KUBECTL_VSPHERE_PASSWORD = $Credential.GetNetworkCredential().Password
    try {
        $loginOutput = & kubectl @kubectlVsphereArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "kubectl-vsphere login failed for Supervisor '$SupervisorName': $($loginOutput -join ' ')"
            return $null
        }
    }
    finally {
        Remove-Item Env:\KUBECTL_VSPHERE_PASSWORD -ErrorAction SilentlyContinue
    }

    $currentContext = (& kubectl config current-context 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $currentContext) {
        Write-Warning "Logged into Supervisor '$SupervisorName' but could not determine the resulting kubectl context."
        return $null
    }
    return $currentContext
}

# kubectl sometimes emits plain-text warnings (e.g. API deprecation notices) on the same stream
# as -o json output. Strip anything before the first '{' so ConvertFrom-Json doesn't choke on it.
function ConvertFrom-KubectlJson {
    param([string[]]$Lines)
    $text = $Lines -join "`n"
    $firstBrace = $text.IndexOf('{')
    if ($firstBrace -gt 0) { $text = $text.Substring($firstBrace) }
    return $text | ConvertFrom-Json -ErrorAction Stop
}

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
if (-not (Get-Module -ListAvailable -Name 'VMware.VimAutomation.Core')) {
    throw "Required PowerCLI module 'VMware.VimAutomation.Core' is not installed. Run: Install-Module VMware.PowerCLI -Scope CurrentUser"
}
Import-Module VMware.VimAutomation.Core -ErrorAction Stop

if ($IgnoreCertificateErrors) {
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -Scope Session | Out-Null
}
Set-PowerCLIConfiguration -ParticipateInCeip $false -Confirm:$false -Scope Session | Out-Null

$kubectlAvailable = $false
if (-not $SkipVKS) {
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        Write-Warning "kubectl not found in PATH - Section 4 (VKS workloads) will be skipped."
    }
    elseif (-not (Get-Command kubectl-vsphere -ErrorAction SilentlyContinue)) {
        Write-Warning "kubectl-vsphere (vSphere Plugin for kubectl) not found in PATH - Section 4 (VKS workloads) will be skipped."
    }
    else {
        $kubectlAvailable = $true
    }
}

if (-not $Credential) {
    $Credential = Get-Credential -Message "Enter credentials for $VIServer"
}

$cisConnection = Connect-CisServer -Server $VIServer -Credential $Credential

try {

    # -----------------------------------------------------------------------
    # 1) vCenter Server Info
    # -----------------------------------------------------------------------
    Write-Section '1) vCenter Server Info'

    $applianceVersion = (Get-CisService -Name 'com.vmware.appliance.system.version' -Server $cisConnection).get()

    [PSCustomObject]@{
        vCenterServer = $VIServer
        Version       = $applianceVersion.version
        Build         = $applianceVersion.build
        InstallTime   = $applianceVersion.install_time
    } | Format-List

    # -----------------------------------------------------------------------
    # 2) vSphere Supervisor Info
    # -----------------------------------------------------------------------
    Write-Section '2) vSphere Supervisor Info'

    $clusterService             = Get-CisService -Name 'com.vmware.vcenter.cluster' -Server $cisConnection
    $supervisorSummaryService   = Get-CisService -Name 'com.vmware.vcenter.namespace_management.supervisors.summary' -Server $cisConnection
    $supervisorTopologyService  = Get-CisService -Name 'com.vmware.vcenter.namespace_management.supervisors.topology' -Server $cisConnection
    $supervisorServicesService  = Get-CisService -Name 'com.vmware.vcenter.namespace_management.supervisors.supervisor_services' -Server $cisConnection
    $supervisorCapabilitiesService = Get-CisService -Name 'com.vmware.vcenter.namespace_management.supervisors.capabilities' -Server $cisConnection
    $namespacesService          = Get-CisService -Name 'com.vmware.vcenter.namespaces.instances' -Server $cisConnection

    $clusterNameByMoid = @{}
    foreach ($clusterSummary in $clusterService.list()) {
        $clusterNameByMoid[$clusterSummary.cluster] = $clusterSummary.name
    }

    $allNamespaces = $namespacesService.list()

    $supervisorIds = $supervisorSummaryService.list().items.supervisor

    $supervisorInventory = New-Object System.Collections.Generic.List[object]

    foreach ($supervisorId in $supervisorIds) {

        $summary  = $supervisorSummaryService.get($supervisorId)
        $topology = $supervisorTopologyService.get($supervisorId)
        $clusterMoid = $topology.clusters | Select-Object -First 1

        $supervisorVersion = $null
        try {
            $supervisorVersion = $supervisorCapabilitiesService.list($supervisorId, $null).version | Select-Object -First 1
        }
        catch {
            Write-Warning "Unable to retrieve Supervisor version (capabilities) for '$($summary.name)': $($_.Exception.Message)"
        }

        $namespaceCount = ($allNamespaces | Where-Object { $topology.clusters -contains $_.cluster } | Measure-Object).Count

        $kubeContext = $null
        if ($kubectlAvailable -and $summary.APIEndpoint) {
            $kubeContext = Connect-SupervisorCluster -SupervisorName $summary.name -ApiServerEndpoint $summary.APIEndpoint -Credential $Credential -IgnoreCertificateErrors:$IgnoreCertificateErrors
        }

        $supervisorInventory.Add([PSCustomObject]@{
            Supervisor         = $summary.name
            SupervisorId       = $supervisorId
            vSphereCluster     = $clusterNameByMoid[$clusterMoid]
            Zone               = $topology.zone
            ApiServerEndpoint  = $summary.APIEndpoint
            KubernetesStatus   = $summary.kubernetes_status
            ConfigStatus       = $summary.config_status
            SupervisorVersion  = $supervisorVersion
            Namespaces         = $namespaceCount
            KubeContext        = $kubeContext
        }) | Out-Null
    }

    if ($supervisorInventory.Count -eq 0) {
        Write-Host "vSphere Supervisor is NOT enabled on $VIServer." -ForegroundColor Yellow
    }
    else {
        $supervisorInventory |
            Select-Object vSphereCluster, Supervisor, SupervisorId, Zone, ApiServerEndpoint, ConfigStatus, SupervisorVersion, Namespaces |
            Format-Table -AutoSize
    }

    # -----------------------------------------------------------------------
    # 3) vSphere Supervisor Services Info
    # -----------------------------------------------------------------------
    Write-Section '3) vSphere Supervisor Services Info'

    if ($supervisorInventory.Count -eq 0) {
        Write-Host 'Skipping - no Supervisor is enabled.' -ForegroundColor Yellow
    }
    else {
        $supervisorServicesReport = foreach ($sv in $supervisorInventory) {
            try {
                $entries = $supervisorServicesService.list($sv.SupervisorId).supervisor_services
                foreach ($entry in $entries) {
                    [PSCustomObject]@{
                        Supervisor        = $sv.Supervisor
                        SupervisorService = $entry.supervisor_service
                        CurrentVersion    = $entry.current_version
                        ConfigStatus      = $entry.config_status
                    }
                }
            }
            catch {
                Write-Warning "Unable to list Supervisor Services for '$($sv.Supervisor)': $($_.Exception.Message)"
            }
        }

        $supervisorServicesReport | Format-Table -AutoSize
    }

    # -----------------------------------------------------------------------
    # 4) vSphere Kubernetes Service (VKS) Workloads
    # -----------------------------------------------------------------------
    Write-Section '4) vSphere Kubernetes Service (VKS) Workloads'

    if ($supervisorInventory.Count -eq 0) {
        Write-Host 'Skipping - no Supervisor is enabled.' -ForegroundColor Yellow
    }
    elseif (-not $kubectlAvailable) {
        Write-Host 'Skipping - kubectl/kubectl-vsphere not available (or -SkipVKS specified).' -ForegroundColor Yellow
    }
    else {
        $vksClusterReport = New-Object System.Collections.Generic.List[object]

        # TanzuKubernetesCluster has shipped under multiple API groups/versions across
        # vSphere releases. Try each until one returns data for a given Supervisor.
        $tkcApiResources = @(
            'cluster.cluster.x-k8s.io',
            'tanzukubernetescluster.run.tanzu.vmware.com'
        )

        foreach ($sv in $supervisorInventory) {

            if (-not $sv.KubeContext) {
                Write-Warning "Not logged into Supervisor '$($sv.Supervisor)' - skipping VKS workload inventory for this Supervisor."
                continue
            }

            $foundAny = $false
            foreach ($apiResource in $tkcApiResources) {
                # stderr is discarded (not merged via 2>&1) since kubectl's own deprecation
                # notices for legacy API resources land on stderr and can interleave into the
                # middle of the -o json stdout output; exit code is the real success signal.
                $output = & kubectl get $apiResource --all-namespaces --context $sv.KubeContext -o json 2>$null
                if ($LASTEXITCODE -ne 0) {
                    Write-Verbose "kubectl get $apiResource returned $LASTEXITCODE for Supervisor '$($sv.Supervisor)'."
                    continue
                }
                if (-not $output) { continue }

                try {
                    $parsed = ConvertFrom-KubectlJson -Lines $output
                }
                catch {
                    Write-Warning "Could not parse 'kubectl get $apiResource' output as JSON for Supervisor '$($sv.Supervisor)'. Raw output: $($output -join ' | ')"
                    continue
                }
                if (-not $parsed.items -or $parsed.items.Count -eq 0) { continue }

                $foundAny = $true
                foreach ($item in $parsed.items) {
                    $guestVersion = $item.spec.distribution.version
                    if (-not $guestVersion) { $guestVersion = $item.spec.topology.version }

                    # Cluster API moved this from a plain `spec.topology.class` string to a
                    # `spec.topology.classRef.name` object in newer (v1beta1/CAPI 1.9+) clusters.
                    $clusterClass = $item.spec.topology.class
                    if (-not $clusterClass) { $clusterClass = $item.spec.topology.classRef.name }

                    # ClusterClass-based Cluster (cluster.x-k8s.io): spec.topology.controlPlane.replicas
                    # + spec.topology.workers.machineDeployments[].replicas / machinePools[].replicas.
                    # Legacy TanzuKubernetesCluster: spec.topology.controlPlane.count / workers.count.
                    $controlPlaneNodes = [int]($item.spec.topology.controlPlane.replicas)
                    if (-not $controlPlaneNodes) { $controlPlaneNodes = [int]($item.spec.topology.controlPlane.count) }

                    $workerNodes = 0
                    if ($item.spec.topology.workers.machineDeployments) {
                        $workerNodes += [int]($item.spec.topology.workers.machineDeployments | Measure-Object -Property replicas -Sum).Sum
                    }
                    if ($item.spec.topology.workers.machinePools) {
                        $workerNodes += [int]($item.spec.topology.workers.machinePools | Measure-Object -Property replicas -Sum).Sum
                    }
                    if ($workerNodes -eq 0 -and $item.spec.topology.workers.count) {
                        $workerNodes = [int]($item.spec.topology.workers.count)
                    }
                    if ($workerNodes -eq 0) { $workerNodes = $null }

                    # The Tanzu Kubernetes Release (TKR) identifier, e.g. "v1.36.1---vmware.4-vkr.5",
                    # is carried as a label (metadata.labels), not an annotation.
                    $vkr = $item.metadata.labels.'run.tanzu.vmware.com/tkr'

                    $vksClusterReport.Add([PSCustomObject]@{
                        Supervisor         = $sv.Supervisor
                        Namespace          = $item.metadata.namespace
                        GuestClusterName   = $item.metadata.name
                        KubernetesVersion  = $guestVersion
                        VKR                = $vkr
                        ClusterClass       = $clusterClass
                        ControlPlaneNodes  = $controlPlaneNodes
                        WorkerNodes        = $workerNodes
                    }) | Out-Null
                }
            }

            if (-not $foundAny) {
                Write-Host "No VKS guest cluster workloads found under Supervisor '$($sv.Supervisor)'." -ForegroundColor Yellow
            }
        }

        if ($vksClusterReport.Count -gt 0) {
            $vksClusterReport | Format-Table -AutoSize
        }
    }
}
finally {
    Disconnect-CisServer -Server $cisConnection -Confirm:$false -ErrorAction SilentlyContinue
}
