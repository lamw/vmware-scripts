Function List-VSANDatastoreFolders {
    # List-DatastoreFolders -DatastoreName WorkloadDatastore
    Param (
        [Parameter(Mandatory=$true)][String]$DatastoreName
    )

    $d = Get-Datastore $DatastoreName
    $br = Get-View $d.ExtensionData.Browser
    $spec = new-object VMware.Vim.HostDatastoreBrowserSearchSpec
    $folderFileQuery= New-Object Vmware.Vim.FolderFileQuery
    $spec.Query = $folderFileQuery
    $fileQueryFlags = New-Object VMware.Vim.FileQueryFlags
    $fileQueryFlags.fileOwner = $false
    $fileQueryFlags.fileSize = $false
    $fileQueryFlags.fileType = $true
    $fileQueryFlags.modification = $false
    $spec.details = $fileQueryFlags
    $spec.sortFoldersFirst = $true
    $results = $br.SearchDatastore("[$($d.Name)]",  $spec)

    $folders = @()
    $files = $results.file
    foreach ($file in $files) {
        if($file.getType().Name -eq "FolderFileInfo") {
            $folderPath = $results.FolderPath + " " + $file.Path

            $tmp = [pscustomobject] @{
                Name = $file.FriendlyName;
                Path = $folderPath;
            }
            $folders+=$tmp
        }
    }
    $folders
}