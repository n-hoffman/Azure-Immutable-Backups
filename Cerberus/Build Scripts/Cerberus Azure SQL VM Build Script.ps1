<#-----------------------------------------------------------------------------------------------------------------------------------
-Introduction:

-    Files included in this package   :
-    Cerberus Azure VM Build List.xlsx (file used to define the VMs to build)
-    <=Script input csv file=> - Save the completed xlsx file to a csv for script execution
-    Cerberus Azure VM Build Script.ps1 (this script, which builds VMs based on the csv input file)
-
-Notes:
-    This script uses the AZ PowerShell module, please ensure that you have the latest version before running
-    The Cerberus Azure VM Build List.xlsx should be populated with VM details and saved as a csv file for script execution
-    The name of the csv file must be referenced in the script
-    Resource Tags defined in the csv will apply to the VM, NIC, and Disks
-    If additional NICs are required, they should be added manually after build
-    If a VM in the CSV already exists, it will be skipped
-    The script contains a non-comprehensive set of error checking capabilities and will throw various errors if conditions are found
-
-Options:
-    This script hard codes Azure Hybrid Use Benefits on Windows Server VMs
-    This script hard codes OS updates to manual setting
-    This script hard codes Boot Diagnostics to default settings
-------------------------------------------------------------------------------------------------------------------------------------#>

#Connect-AzAccount #Connect to Azure using an account with permission to build resources in the defined Resource Group(s) / subscriptions

#import csv - This section defines the location and name of the input CSV file
Set-Location -Path "C:\users\Neil-Insentra\OneDrive - Insentra Pty Ltd\Project Work\Cerberus - IPM\Azure DR Project 1\Build Scripts\Uploaded" # Optionally set the csv path
$VMs = import-csv .\SQLTest.csv # If using set-path option, no path is needed. Alternatively, the entire path can be defined here.
#endregion

#begin processing
Foreach ($v in $VMs) {
    #Gather Variables
    $VMSubscriptionId = $v.SubscriptionID    
    $VMResourceGroupName = $v.VMResourceGroupName
    $VMRegion = $v.Region
    $VMName = $v.VMName
    $VMSize = $v.VMSize
    $OS = $v.OS
    $OsVersion = $v.Version
    $SQL = $v.SQL
    $VnetName = $v.VnetName
    $VnetRG = $v.VnetRG
    $SubnetName = $v.SubnetName
    $VMZone = $v.Zone
    $VMAvailabilitySetName = $v.AvailabilitySetName
    $VMIPaddress = $v.IPAddress
    $VMTrustedLaunch = $v.TrustedLaunch
    $LocalAdminUser = $v.LocalAdminUser
    $LocalAdminPW = $v.LocalAdminPW
    $Disk1 = $v.Disk1
    $Disk1SKU = $v.Disk1SKU
    $Disk1GB = $v.Disk1GB
    $Disk1Cache = $v.Disk1Cache
    $Disk2 = $v.Disk2
    $Disk2SKU = $v.Disk2SKU
    $Disk2GB = $v.Disk2GB
    $Disk2Cache = $v.Disk2Cache
    $Disk3 = $v.Disk3
    $Disk3SKU = $v.Disk3SKU
    $Disk3GB = $v.Disk3GB
    $Disk3Cache = $v.Disk3Cache
    $Disk4 = $v.Disk4
    $Disk4SKU = $v.Disk4SKU
    $Disk4GB = $v.Disk4GB
    $Disk4Cache = $v.Disk4Cache
    $Disk5 = $v.Disk5
    $Disk5SKU = $v.Disk5SKU
    $Disk5GB = $v.Disk5GB
    $Disk5Cache = $v.Disk5Cache
    $VMLocalAdminSecurePassword = ConvertTo-SecureString $LocalAdminPW -AsPlainText -Force
    $VMCredential = New-Object System.Management.Automation.PSCredential ($LocalAdminUser, $VMLocalAdminSecurePassword)
    $VMNicName = "$VMName-nic"
    #endregion

    #Testing
    $CurrentSubscriptionID = (Get-AzContext).Subscription.Id
    if ($VMSubscriptionId -ne $CurrentSubscriptionID) {
        Try {
            Get-AzSubscription -SubscriptionId $VMSubscriptionId | Select-AzSubscription
        }
        Catch {
            Write-Output "Subscription $VMSubscription does not exist. Exiting..."
            Break
        }
    }
    Try {
        $VnetConfig = Get-AzVirtualNetwork -Name $VnetName -ResourceGroupName $VnetRG -ErrorAction Stop
    }
    Catch {
        Write-Output "Virtual Network $VnetName does not exist, create Virtual Network. Exiting..."
        Break
    }

    Try {
        $SubnetConfig = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VnetConfig -Name $SubnetName -ErrorAction Stop 
    }
    Catch {
        Write-Output "Subnet $SubnetName does not exist, create Subnet. Exiting..."
        Break
    }

    Try {
        $VMRGTest = Get-AzResourceGroup -Name $VMResourceGroupName -ErrorAction Stop
    }
    Catch {
        Write-Output "Resource Group $VMResourceGroupName does not exist, create Resource Group with proper tags. Exiting..."
        Break
    }

    $VMTest = Get-AzVM -Name $VMName -ResourceGroupName $VMResourceGroupName -ErrorAction SilentlyContinue

    if ($VMTest) {
        Write-Output "Virtual Machine $VMName already exists. Skipping..."
        Continue
    }

    if ($VMAvailabilitySetName) {
        $AVTest = Get-AzAvailabilitySet -Name $VMAvailabilitySetName -ResourceGroupName $VMResourceGroupName -ErrorAction SilentlyContinue
        if (!($VMAvailabilitySetName)) {
            Write-Output "Availability Set $VMAvailabilitySetName does not exist.  Exiting..."
            Break
        }
    }
    if ($VMAvailabilitySetName -and $VMZone) {
        Write-Output "Virtual Machine $VMName is configured for Availability Set and Availability Zone. Skipping $VMName..."
        Continue
    }
    #endregion

    ######################################
    
    #Build VM    
    $Vnet = Get-AzVirtualNetwork -Name $VnetName -ResourceGroupName $VnetRG
    if ($OS -eq "Windows") {
        if ($VMIPaddress) {
            Try {
                $VmNic = New-AzNetworkInterface -Name $VMNicName -ResourceGroupName $VMResourceGroupName -Location $VMRegion -SubnetId $SubnetConfig.Id -PrivateIpAddress $VMIPaddress -ErrorAction Stop
            }
            Catch {
                Write-host "NIC creation failed for $VMName with the following error:" -ForegroundColor Magenta
                Write-host $Error[0].Exception.Message -ForegroundColor Yellow
                Write-host "Aborting Script..." -ForegroundColor Magenta

                Break           
            }
        }
        else {
            $VmNic = New-AzNetworkInterface -Name $VMNicName -ResourceGroupName $VMResourceGroupName -Location $VMRegion -SubnetId $SubnetConfig.Id
        $VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize -LicenseType Windows_Server
        }
        if($SQL) {
            $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftSQLServer' -Offer $SQL -Skus enterprise-gen2 -Version latest
        }
        else {
            $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus $OsVersion -Version latest
        }        
        $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $VMCredential -ProvisionVMAgent -PatchMode Manual -EnableAutoUpdate:$false
        $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $VmNic.Id        
        $VirtualMachine = Set-AzVMBootDiagnostic -VM $VirtualMachine -Enable
        if ($VMTrustedLaunch) {        
            $VirtualMachine = Set-AzVMSecurityProfile -VM $VirtualMachine -SecurityType TrustedLaunch 
            $VirtualMachine = Set-AzVMUefi -VM $VirtualMachine -EnableVtpm $true -EnableSecureBoot $true 
        }
        if ($Disk1) {
            $DataDisk1Name = $VMName + '_datadisk1'
            if ($VMZone) {
                $DataDisk1Config = New-AzDiskConfig -SkuName $Disk1SKU -Location $VMRegion -CreateOption Empty -DiskSizeGB $Disk1GB -Zone $VMZone
            }
            else {
                $DataDisk1Config = New-AzDiskConfig -SkuName $Disk1SKU -Location $VMRegion -CreateOption Empty -DiskSizeGB $Disk1GB
            }
            $DataDisk1 = New-AzDisk -DiskName $DataDisk1Name -Disk $DataDisk1Config -ResourceGroupName $VMResourceGroupName
            Add-AzVMDataDisk -VM $VirtualMachine -Name $DataDisk1Name -CreateOption Attach -ManagedDiskId $DataDisk1.Id -Lun 1 -Caching $Disk1Cache 
        }
        if ($Disk2) {
            $DataDisk2Name = $VMName + '_dataDisk2'
            if ($VMZone) {
                $DataDisk2Config = New-AzDiskConfig -SkuName $Disk2SKU -Location $VMRegion -CreateOption Empty -DiskSizeGB $Disk2GB -Zone $VMZone
            }
            else {
                $DataDisk2Config = New-AzDiskConfig -SkuName $Disk2SKU -Location $VMRegion -CreateOption Empty -DiskSizeGB $Disk2GB
            }
            $DataDisk2 = New-AzDisk -DiskName $DataDisk2Name -Disk $DataDisk2Config -ResourceGroupName $VMResourceGroupName
            Add-AzVMDataDisk -VM $VirtualMachine -Name $DataDisk2Name -CreateOption Attach -ManagedDiskId $DataDisk2.Id -Lun 2 -Caching $Disk2Cache 
        }
        if ($Disk3) {
            $DataDisk3Name = $VMName + '_dataDisk3'
            if ($VMZone) {
                $DataDisk3Config = New-AzDiskConfig -SkuName $Disk3SKU -Location $VMRegion -CreateOption Empty -DiskSizeGB $Disk3GB -Zone $VMZone
            }
            else {
                $DataDisk3Config = New-AzDiskConfig -SkuName $Disk3SKU -Location $VMRegion -CreateOption Empty -DiskSizeGB $Disk3GB
            }
            $DataDisk3 = New-AzDisk -DiskName $DataDisk3Name -Disk $DataDisk3Config -ResourceGroupName $VMResourceGroupName
            Add-AzVMDataDisk -VM $VirtualMachine -Name $DataDisk3Name -CreateOption Attach -ManagedDiskId $DataDisk3.Id -Lun 3 -Caching $Disk3Cache 
        }
        if ($Disk4) {
            $DataDisk4Name = $VMName + '_dataDisk4'
            if ($VMZone) {
                $DataDisk4Config = New-AzDiskConfig -SkuName $Disk4SKU -Location $VMRegion -CreateOption Empty -DiskSizeGB $Disk4GB -Zone $VMZone
            }
            else {
                $DataDisk4Config = New-AzDiskConfig -SkuName $Disk4SKU -Location $VMRegion -CreateOption Empty -DiskSizeGB $Disk4GB
            }
            $DataDisk4 = New-AzDisk -DiskName $DataDisk4Name -Disk $DataDisk4Config -ResourceGroupName $VMResourceGroupName
            Add-AzVMDataDisk -VM $VirtualMachine -Name $DataDisk4Name -CreateOption Attach -ManagedDiskId $DataDisk4.Id -Lun 4 -Caching $Disk4Cache 
        }
        if ($Disk5) {
            $DataDisk5Name = $VMName + '_dataDisk5'
            if ($VMZone) {
                $DataDisk5Config = New-AzDiskConfig -SkuName $Disk5SKU -Location $VMRegion -CreateOption Empty -DiskSizeGB $Disk5GB -Zone $VMZone
            }
            else {
                $DataDisk5Config = New-AzDiskConfig -SkuName $Disk5SKU -Location $VMRegion -CreateOption Empty -DiskSizeGB $Disk5GB
            }
            $DataDisk5 = New-AzDisk -DiskName $DataDisk5Name -Disk $DataDisk5Config -ResourceGroupName $VMResourceGroupName
            Add-AzVMDataDisk -VM $VirtualMachine -Name $DataDisk5Name -CreateOption Attach -ManagedDiskId $DataDisk5.Id -Lun 5 -Caching $Disk5Cache 
        }
        if ($VMZone) {
            New-AzVM -ResourceGroupName $VMResourceGroupName -Location $VMRegion -VM $VirtualMachine -Zone $VMZone -Verbose
        }
        elseif ($VMAvailabilitySetName) {
            New-AzVM -ResourceGroupName $VMResourceGroupName -Location $VMRegion -VM $VirtualMachine -AvailabilitySetName $VMAvailabilitySetName -Verbose
        }
        else {
            New-AzVM -ResourceGroupName $VMResourceGroupName -Location $VMRegion -VM $VirtualMachine -Verbose
        }
        if ($SQL){
            New-AzSqlVM -ResourceGroupName $VMResourceGroupName -Location $VMRegion -Name $VMName -LicenseType AHUB -Sku Enterprise -SqlManagementType Full
        }
        #endregion
    
        #Write Tags to VM and its resources
        $ApplicationTag = $v.Tag_Application
        $EnvironmentTag = $v.Tag_Environment
        $DepartmentTag = $v.Tag_Department
        $CreatorTag = $v.Tag_Creator

        $VMtags = @{"Application" = $ApplicationTag; "Environment" = $EnvironmentTag ; Department = $DepartmentTag ; "Creator" = $CreatorTag }
        $NewVM = Get-AzVM -ResourceGroupName $VMResourceGroupName -name $VMName
        Write-Output "Updating Tags for VM $VMName"
        Update-AzTag -ResourceId $NewVM.Id -Operation Merge -Tag $VMtags
        foreach ($nic in $NewVM.NetworkProfile.NetworkInterfaces) {
            Write-Output "Updating $VMName NIC Tags"
            Update-AzTag -ResourceId $nic.Id -Operation Merge -Tag $VMtags
        }
        if ($NewVM.StorageProfile.OsDisk.ManagedDisk.Id) {
            Write-Output "Updating $VMName OS Disk Tags"
            Update-AzTag -ResourceId $NewVM.StorageProfile.OsDisk.ManagedDisk.Id -Operation Merge -Tag $VMtags
        }
        foreach ($disk in $NewVM.StorageProfile.DataDisks) {
            Write-Output "Updating $NewVM Data Disk Tags"
            $azResource = Get-AzResource -Name "$($disk.Name)"
            Update-AzTag -ResourceId $azResource.Id -Operation Merge -Tag $VMtags
        }
        #endregion
    }
    #endregion
}


