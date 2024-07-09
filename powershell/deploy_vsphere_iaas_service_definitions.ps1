$vsphere_iaas_service_yamls = @(
    "https://vmwaresaas.jfrog.io/artifactory/supervisor-services/cci-supervisor-service/v1.0.0/cci-supervisor-service.yml"
    "https://vmwaresaas.jfrog.io/ui/api/v1/download?repoKey=supervisor-services&path=harbor/v2.9.1/harbor.yml"
    "https://vmwaresaas.jfrog.io/ui/api/v1/download?repoKey=supervisor-services&path=ca-clusterissuer/v0.0.2/ca-clusterissuer.yml"
    "https://vmwaresaas.jfrog.io/ui/api/v1/download?repoKey=supervisor-services&path=contour/v1.28.2/contour.yml"
    "https://vmwaresaas.jfrog.io/ui/api/v1/download?repoKey=supervisor-services&path=external-dns/v0.13.4/external-dns.yml"
    "https://vmwaresaas.jfrog.io/ui/api/v1/download?repoKey=supervisor-services&path=nsx-management-proxy/v0.1.1/nsx-management-proxy.yml"
    "https://raw.githubusercontent.com/vsphere-tmm/Supervisor-Services/main/supervisor-services-labs/argocd-operator/v0.8.0/argocd-operator.yaml"
    "https://raw.githubusercontent.com/vsphere-tmm/Supervisor-Services/main/supervisor-services-labs/external-secrets-operator/v0.9.14/external-secrets-operator.yaml"
    "https://raw.githubusercontent.com/vsphere-tmm/Supervisor-Services/main/supervisor-services-labs/rabbitmq-operator/v2.8.0/rabbitmq-operator.yaml"
    "https://raw.githubusercontent.com/vsphere-tmm/Supervisor-Services/main/supervisor-services-labs/redis-operator/v0.16.0/redis-operator.yaml"
    "https://raw.githubusercontent.com/vsphere-tmm/Supervisor-Services/main/supervisor-services-labs/keda/v2.13.1/keda.yaml"
    "https://raw.githubusercontent.com/vsphere-tmm/Supervisor-Services/main/supervisor-services-labs/grafana-operator/v5.9.0/grafana-operator.yaml"
)

$ss = Get-CisService com.vmware.vcenter.namespace_management.supervisor_services

$count = 1
foreach ($vsphere_iaas_service_yaml in $vsphere_iaas_service_yamls) {
    $splitUrl = $vsphere_iaas_service_yaml -split '/'
    Write-Host -ForegroundColor Cyan "Processing $($splitUrl[-1]) (${count}/$(${vsphere_iaas_service_yamls}.count)) ..."

    $request = Invoke-WebRequest -Uri $vsphere_iaas_service_yaml
    if($request.StatusCode -eq 200) {
        $rawYaml = $request.Content
        $encodedYaml = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($rawYaml))

        $carvelSpec = $ss.Help.create.spec.carvel_spec.Create()
        $carvelSpec.version_spec.content = $encodedYaml

        $spec = $ss.Help.create.spec.Create()
        $spec.carvel_spec = $carvelSpec

        Write-Host -ForegroundColor Green "`tDeploying $(($rawYaml|ConvertFrom-YAML).metadata.name) ..."
        $ss.create($spec)
        $count++
    }
}