# Immutable-Container-Copy-VM
These sample scripts will copy data into an Azure storage account. The storage account container is meant to have a time-based immutable retention policy. The intent is to create a safety copy of a VM disks, SQL DBs, etc to protect from deletion of Azure resources by a malicious actor. This could compliment an existing BCDR strategy. Additional logic would be required to purge older backups that fall out of retention, I will add sample code for this soon.

Files in this Project so far: 

Azure-Immutable-Copy-VM.ps1 - Copy disks from one or more VMs (OS and Data Disks)

Azure-Immutable-Copy-SQL.ps1 - Copy one or more SQL databases
