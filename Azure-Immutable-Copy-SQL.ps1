#copy-SQL
#begin variables
$SQLResourceGroup = "ImmutableTest" #RG of the SQL Server
$StorageAccountResourceGroup = "ImmutableTest" #Storage Account containing the immutable container
$SQLServerName = "xxxxxxxxxxxxxxx" #SQL Server name
$SQLUsername = "xxxxxxxxxxxxxxx" #SQL admin account
$SQLPassword = "xxxxxxxxxxxxxxx" #SQL admin password - can also reference a key vault secret
$DatabaseNames = "DB1" #DBs to protect, for multiple DBs, use ("DB1","DB2")
$StorageAccount = "xxxxxxxxxxxxxxx"#Storage Account containing the immutable container
$StorageAccountContainer = "3day-retention"#Immutable Container Name
#endregion
#begin processing
$SecurePassword = ConvertTo-SecureString -String $SQLPassword -AsPlainText -Force
$SQLCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $SQLUsername, $SecurePassword
$Date = Get-Date -format MMddyyyy
$AllDBs = Get-AzSqlDatabase -ServerName $SQLServerName -ResourceGroupName $SQLResourceGroup
foreach ($D in $AllDBs) {
    $DBName = $D.DatabaseName
    if ($DatabaseNames -notcontains $DBName) {
        Write-Host "$DBName not marked for copy, skipping..."
        Continue 
    }
    $DatabaseName = $D.DatabaseName
    $StorageAccountKey = (Get-AzStorageAccountKey -Name $StorageAccount -ResourceGroupName $StorageAccountResourceGroup).value[0]
    $DatabaseCopyName = "$DatabaseName-Copy"
    $BacpacFilename = "$DatabaseCopyName.bacpac"
    $BaseStorageUri = "https://" + $StorageAccount + ".blob.core.windows.net"
    $BacpacURI = "$BaseStorageUri/$StorageAccountContainer/$Date/$BacpacFilename"
    $BacpacURI = "$BaseStorageUri/test/$Date/$BacpacFilename"
    Write-Host "Copying" $DatabaseName "to" $DatabaseCopyName
    New-AzSqlDatabaseCopy -ResourceGroupName $SQLResourceGroup -ServerName $SQLServerName -DatabaseName $DatabaseName -CopyResourceGroupName $SQLResourceGroup -CopyServerName $SQLServerName -CopyDatabaseName $DatabaseCopyName
    Write-Host "Copy completed"
    Write-Host "Exporting" $DatabaseCopyName "to" $BacpacUri
    $ExportRequest = New-AzSqlDatabaseExport -ResourceGroupName $SQLResourceGroup -ServerName $SQLServerName -DatabaseName $DatabaseCopyName -StorageKeyType "StorageAccessKey" -StorageKey $StorageAccountKey -StorageUri $BacpacUri -AdministratorLogin $SQLCredentials.UserName -AdministratorLoginPassword $SQLCredentials.Password
    $ExportRequest = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $ExportRequest.OperationStatusLink
    while ($ExportRequest.Status -eq "InProgress")
    {
        Start-Sleep -s 10
        $ExportRequest = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $ExportRequest.OperationStatusLink
    }
    Remove-AzSqlDatabase -ResourceGroupName $SQLResourceGroup -ServerName $SQLServerName -DatabaseName $DatabaseCopyName
}
#endregion