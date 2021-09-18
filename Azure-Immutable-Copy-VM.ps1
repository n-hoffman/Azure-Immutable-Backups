#copy VMs
#begin variables
$SnapshotResourceGroupName = "ImmutableTest" #Where to store the Snapshots, script will create if not exist
$Location = "westus2" #Location of the Snapshot RG, Should be same as VMs and Storage Account
$VMNames = "VM1" #VMs to protect, for multiple VMs, use ("VM1","VM2")
$StorageAccount = "xxxxxxxxxxxxxxx" #Storage Account containing the immutable container
$StorageAccountResourceGroup = "ImmutableTest" #Storage Account RG containing the immutable container
$StorageAccountContainer = "3day-retention" #Immutable Container Name
#endregion
#create resource group if not exist
Try { Get-AzResourceGroup -Name  $SnapshotResourceGroupName -Location $Location -ErrorAction Stop }
Catch { New-AzResourceGroup -Name  $SnapshotResourceGroupName -Location $Location }
#endregion
#begin processing
$Date = Get-Date -format MMddyyyy
$AllVMs = Get-AzVM 
foreach ($v in $AllVMs) {
    $VMName = $V.Name
    if ($VMNames -notcontains $VMName) {
        Write-Host "$VMName not marked for copy, skipping..."
        Continue 
    }
    $VMResourceGroup = $v.ResourceGroupName
    $VMSnapshotName = "$VMName`_OSDisk"
    $VM = Get-AzVM -ResourceGroupName $VMResourceGroup -Name $VMName
    $VMSnapshotCapture = New-AzSnapshotConfig -SourceUri $VM.StorageProfile.OsDisk.ManagedDisk.Id -Location $location -CreateOption copy
    New-AzSnapshot -Snapshot $VMSnapshotCapture -SnapshotName $VMSnapshotName -ResourceGroupName $SnapshotResourceGroupName
    $VMDataDisks = $vm.StorageProfile.DataDisks
    foreach ($VMDataDisk in $VMDataDisks) {
        $DDName = $VMDataDisk.name
        $DD = Get-Azdisk -DiskName $VMDataDisk.name -ResourceGroupName $VMResourceGroup
        $DataDiskSnapshotConfig = New-AzSnapshotConfig -SourceUri $DD.Id -CreateOption Copy -Location $Location
        $DDSnapshotName = "$VMName`_$DDName"
        New-AzSnapshot -SnapshotName $DDSnapshotName -Snapshot $DataDiskSnapshotConfig -ResourceGroupName $SnapshotResourceGroupName
    }
}
#endregion
#copy snapshots
$StorageAccountKey = (Get-AzStorageAccountKey -Name $storageaccount -ResourceGroupName $StorageAccountResourceGroup).value[0]
$snapshots = Get-AzSnapshot -ResourceGroupName $SnapshotResourceGroupName #| ? { ($_.TimeCreated) -gt ([datetime]::UtcNow.Addhours(-12)) }
foreach ($Snapshot in $Snapshots) {    
    Write-Output "Granting $($snapshot.name) access"
    $snapshotaccess = Grant-AzSnapshotAccess -ResourceGroupName $SnapshotResourceGroupName -SnapshotName $snapshot.Name -DurationInSecond 3600 -Access Read -ErrorAction stop 
    Write-Output "$($snapshot.name) access granted"
    $DestStorageContext = New-AzStorageContext –StorageAccountName $storageaccount -StorageAccountKey $StorageAccountKey -ErrorAction stop
    $vhdname = $Snapshot.Name
    Write-Output "Begin snapshot: ($($snapshot.name)) copy to $vhdname.vhd"
    Start-AzStorageBlobCopy -AbsoluteUri $snapshotaccess.AccessSAS -DestContainer $StorageAccountContainer -DestContext $DestStorageContext -DestBlob "$Date/$($vhdname).vhd" -Force -ErrorAction stop
    Write-Output "snapshot: ($($snapshot.name)) copy to $vhdname.vhd completed"
    Revoke-AzSnapshotAccess -ResourceGroupName $SnapshotResourceGroupName -SnapshotName $snapshot.Name
    Remove-AzSnapshot -ResourceGroupName $SnapshotResourceGroupName -SnapshotName $snapshot.Name -force 
}  
#endregion
