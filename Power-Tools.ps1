#Power-Tools.ps1
#Author: Jared Brogan
#Version: 1.5


$Global:ProgressPreference = 'SilentlyContinue'
#Check for new versions on github
$githubLink = "https://raw.githubusercontent.com/jaredbrogan/PowerCLI/dev/Power-Tools.ps1"
$tempFile = "C:\Temp\versionCheck.txt"
Invoke-WebRequest -Uri $githubLink -outfile $tempFile
$webVersion = Select-String -Path $tempFile -Pattern 'Version:' | ForEach-Object {$_.Line} | Select-Object -First 1
$runVersion = Select-String -Path $PSCommandPath -Pattern 'Version:' | ForEach-Object {$_.Line} | Select-Object -First 1
Write-Host "`n******************************`n"
Write-Host "Power-Tools`n"
Write-Host "Github: $webVersion"
Write-Host "Running: $runVersion"

if ($webVersion -ne  $runVersion){
    Write-Host "Newer version is available"
    Write-Host `n$githubLink`n
    Start-Process "https://github.com/jaredbrogan/PowerCLI/"
}

Remove-Item $tempFile
#Start-Sleep -Seconds 3

$pauseSeconds=$null
$continue=$null
$createSnapshotsName=$null
$removeSnapshotsName=$null

$auditSnapshots="Audit Snapshots"
$auditHotAdd="Audit Hot-Add"
$auditTimeSync="Audit Time Sync"
$auditOSVersion="Audit OS Version"
$createSnapshots="Create Snapshots"
$removeSnapshots="Remove Snapshots"
$enableTimeSync="Enable Time Sync"
$enableHotAdd="**Enable Hot Add"
$updateMEM="**Update Memory in GBs"
$updateCPU="**Update CPU Cores"
$updateOsVersion="**Configure OS Version"
$rollingReboot="**Execute Rolling Reboot"
$shutdown="**Execute Shutdown"
$startup="Execute Startup"
$acceptableOS="oracleLinux64Guest","rhel6_64Guest","windows9Server64Guest","windows8Server64Guest","oracleLinux7_64Guest"


$currentVM = 0

function Get-Options {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Virtual Machine Actions'
    $form.Size = New-Object System.Drawing.Size(300,340)
    $form.StartPosition = 'CenterScreen'
    
    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Point(75,250)
    $OKButton.Size = New-Object System.Drawing.Size(75,23)
    $OKButton.Text = 'OK'
    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $OKButton
    $form.Controls.Add($OKButton)
    
    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Point(150,250)
    $CancelButton.Size = New-Object System.Drawing.Size(75,23)
    $CancelButton.Text = 'Cancel'
    $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $CancelButton
    $form.Controls.Add($CancelButton)
    
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10,20)
    $label.Size = New-Object System.Drawing.Size(280,20)
    $label.Text = 'Actions with ** will shutdown VM'
    $form.Controls.Add($label)
    
    $listBox = New-Object System.Windows.Forms.Listbox
    $listBox.Location = New-Object System.Drawing.Point(10,40)
    $listBox.Size = New-Object System.Drawing.Size(260,20)
    
    $listBox.SelectionMode = 'MultiExtended'

    [void] $listBox.Items.Add($auditSnapshots)
    [void] $listBox.Items.Add($auditHotAdd)
    [void] $listBox.Items.Add($auditTimeSync)
    [void] $listBox.Items.Add($auditOSVersion)
    [void] $listBox.Items.Add($createSnapshots)
    [void] $listBox.Items.Add($removeSnapshots)
    [void] $listBox.Items.Add($enableTimeSync)       
    [void] $listBox.Items.Add($enableHotAdd)
    [void] $listBox.Items.Add($updateMEM) 
    [void] $listBox.Items.Add($updateCPU)     
    [void] $listBox.Items.Add($updateOsVersion)
    [void] $listBox.Items.Add($rollingReboot)
    [void] $listBox.Items.Add($shutdown)            
    [void] $listBox.Items.Add($startup)
    
    
    $listBox.Height = 200
    $form.Controls.Add($listBox)
    $form.Topmost = $true
    
    $result = $form.ShowDialog()
    
    if ($result -eq [System.Windows.Forms.DialogResult]::OK)
    {
        return $listBox.SelectedItems
    } 
}

function Get-File {
    Add-Type -AssemblyName System.Windows.Forms
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
        InitialDirectory = [Environment]::GetFolderPath('mydocuments') 
        Filter = 'CSV Files (*.csv)|*.csv'
    }
    $null = $FileBrowser.ShowDialog()
    return $FileBrowser.FileName
}

Write-Host "`n************************************************************"
Write-Host "* Select the .csv file containing VM and vCenter to modify *"
Write-Host "* The reports will be saved in this directory              *"
Write-Host "************************************************************"

$vmnamesfile = Get-File #CSV file of the VM's
if(!$vmnamesfile){
    Exit
}
$vmnamesfileName = Split-Path -Path $vmnamesfile -Leaf -Resolve
$workingDirectory = "$(Split-Path $vmnamesfile)\$($vmnamesfileName -replace '.csv','')"
if(!(test-path $workingDirectory))
{
    New-Item -ItemType Directory -Force -Path $workingDirectory | Out-Null
}
$timeStamp = "$((get-date).dayofyear)_$((get-date).hour)_$((get-date).minute)"
$hotfile = "$workingDirectory\hotReport_$timeStamp.csv" #CSV file of the VM's hot-add
$timefile = "$workingDirectory\timeReport_$timeStamp.csv" #CSV file of the VM's time sync
$guestOSfile = "$workingDirectory\osReport_$timeStamp.csv" #CSV file of the VM's configured and running OS
$snapshotfile = "$workingDirectory\snapshotReport_$timeStamp.csv" #CSV file of the VM's snapshot
$vmnames = Import-Csv $vmnamesfile #Read the CSV File into a variable
$vcenters = $vmnames | Select-Object -ExpandProperty vCenter -Unique #Read the vCenters contained in the CSV and dedupe them
$totalVMs = $vmnames.VM.count

Write-Host "`n************************************************************"
Write-Host "* Select the actions to execute from dialogue box          *"
Write-Host "* Utilize shift / ctrl to select multiple options          *"
Write-Host "************************************************************"
$options = Get-Options

if (!$options){
    Write-Host "[ERROR] No options have been selected.  Exiting."
    Exit
}
else{

    #Confirming Actions
    Write-Host "`n[INFO] VM's from $vmnamesfile`n" $vmnames.VM
    $list = $options -join "`n "
    Write-Host "`n[INFO] selected options:`n" $list
    while (!$continue) {
        $continue = Read-Host -Prompt `n'[INPUT] Do you wish to continue (y/n)?'
        if ($continue -eq "n"){
            Exit
        }
        elseif ($continue -eq "y"){
            Write-Host "[INFO] Executing"
        }
        else {$continue=$null}
    }
    
    #Log into each vCenter included in the CSV file
    $cred=Get-Credential
    foreach ($vcenter in $vcenters) {
        Connect-VIServer $vcenter -Credential $cred
    }

    #options that require foreach
    if (($options -eq $createSnapshots) -or ($options -eq $removeSnapshots) -or ($options -eq $auditTimeSync) -or ($options -eq $rollingReboot) -or ($options -eq $enableHotAdd) -or ($options -eq $shutdown) -or ($options -eq $startup) -or ($options -eq $updateMEM) -or ($options -eq $updateCPU) -or ($options -eq $updateOsVersion)) {

        if (($options -eq $rollingReboot) -or ($options -eq $enableHotAdd) -or ($options -eq $updateMEM) -or ($options -eq $updateCPU) -or ($options -eq $updateOsVersion)) {
            #get the time between SSH or RDP connection and next shutdown
            while (!$pauseSeconds) {
                $pauseSeconds = Read-Host -Prompt `n'[INPUT] Seconds between SSH / RDP connection and next shutdown'
            }
        }
        else{
            $pauseSeconds = 0
        }
        
        #Get snapshots names from user
        if ($options -eq $createSnapshots){
            while (!$createSnapshotsName){
                $createSnapshotsName = Read-Host -Prompt `n'[INPUT] Name of snapshots to create'
            }
        }
        if ($options -eq $removeSnapshots){
            while (!$removeSnapshotsName){
                $removeSnapshotsName = Read-Host -Prompt `n'[INPUT] Name of snapshots to remove'
            }
        }     

        #Execution per VM
        foreach ($vmname in $vmnames) {
            $currentVM = $currentVM + 1
            Write-Host "`n******************************"
            Write-Host "[INFO]" $vmname.VM
            Write-Host "[INFO] $currentVM of $totalVMs"

            $vm = Get-VM -Name $vmname.VM
            if ($vm){
                #REMOVE SNAPSHOT
                if ($options -eq $removeSnapshots){
                    Write-Host "[INFO] Remove Snapshot"
                    Get-VM $vmname.VM | Get-Snapshot -Name $removeSnapshotsName | Remove-Snapshot -Confirm:$false
                }

                #MAKE SNAPSHOT
                if ($options -eq $createSnapshots){
                    Write-Host "[INFO] Create Snapshot:"  
                    Get-VM $vmname.VM | New-Snapshot -Name $createSnapshotsName -Memory:$false -Quiesce:$false
                }

                #ENABLE Time Sync
                if ($options -eq $enableTimeSync){
                    Write-Host "[INFO] Update TimeSync configuration"            
                    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
                    $spec.tools = New-Object VMware.Vim.ToolsConfigInfo
                    $spec.tools.syncTimeWithHost = $true
                    $vm.ExtensionData.ReconfigVM_Task($spec) | Out-Null
                }

                #AUDIT Time Sync with Host 
                if ($options -eq $auditTimeSync){
                    Write-Host "[INFO] Audit TimeSync configuration"     
                    Get-View -viewtype virtualmachine -Filter @{'name'=$vmname.VM} | Select-Object name,@{N='ToolsConfigInfo';E={$_.Config.Tools.syncTimeWithHost } } | Export-Csv -Append -Path $timefile -NoTypeInformation
                }

                #Rolling Reboot or Shutdown or HotAdd
                if (($options -eq $rollingReboot) -or ($options -eq $shutdown) -or ($options -eq $enableHotAdd) -or ($options -eq $updateMEM) -or ($options -eq $updateCPU) -or ($options -eq $updateOsVersion)) {
                    #Shutdown Server if Required
                    $status = $vm.PowerState
                    if ($status -eq "PoweredOn") {
                        Shutdown-VMGuest -VM $vmname.VM -Confirm:$False | Out-Null
                        Write-Host "[INFO] Waiting on shutdown for VM:" $vmname.VM
                        do { 
                            Start-Sleep -s 5
                            $vm = Get-VM -Name $vmname.VM
                            $status = $vm.PowerState
                            Write-Host "[INFO] Powerstate for" $vmname.VM "is:" $status
                        }until($status -eq "PoweredOff")
                    }
                    elseif ($status -eq "PoweredOff") {
                        Write-Host "[INFO] Powerstate for" $vmname.VM "is:" $status
                    }
                }

                #Hot Add
                if ($options -eq $enableHotAdd) {
                    Write-Host "[INFO] Update HotAdd configuration"
                    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
                    $spec.memoryHotAddEnabled = $true
                    $spec.cpuHotAddEnabled = $true
                    $vm.ExtensionData.ReconfigVM_Task($spec) | Out-Null
                }

                #Configure OS Version if OS version value is acceptable
                if (($options -eq $updateOsVersion) -and ($null -ne $($acceptableOS.Where({$vmname.OS -eq $_}, 'SkipUntil', 1)))) {
                    Write-Host "[INFO] Configure OS Version"
                    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
                    $spec.DeviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec[] (0)
                    $spec.CpuFeatureMask = New-Object VMware.Vim.VirtualMachineCpuIdInfoSpec[] (0)
                    $spec.GuestId = $vmname.OS
                    $vm.ExtensionData.ReconfigVM_Task($spec) | Out-Null
                }   

                #Update Memory
                if (($options -eq $updateMEM) -and ($vmname.MEM)) {
                    Write-Host "[INFO] Update Memory configuration"
                    Get-VM -Name $vmname.VM | Set-VM -MemoryGB $vmname.MEM -Confirm:$false | Out-Null
                }
                

                #Update CPU
                if (($options -eq $updateCPU) -and ($vmname.CPU)) {
                    Write-Host "[INFO] Update CPU configuration"
                    Get-VM -Name $vmname.VM | Set-VM -NumCPU $vmname.CPU -Confirm:$false | Out-Null
                }                        

                #Rolling Reboot of Startup or HotAdd
                if (($options -eq $rollingReboot) -or ($options -eq $startup) -or ($options -eq $enableHotAdd) -or ($options -eq $updateMEM) -or ($options -eq $updateCPU) -or ($options -eq $updateOsVersion)) {
                    #Start Node
                    Start-VM -VM $vmname.VM | Out-Null
                    Write-Host "[INFO] Wait while" $vmname.VM "starts up."
                    do {
                        $statusSSH = test-netconnection $vmname.VM -port 22 -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                        $statusRDP = test-netconnection $vmname.VM -port 3389 -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 
                        Start-Sleep -s 1
                    } until ($statusSSH.TCPTestSucceeded -or $statusRDP.TCPTestSucceeded)
                    Write-Host "[INFO] The server" $vmname.VM "has finished starting up." 
                }
                #Wait time between SSH or RDP connection and next shutdown
                Start-Sleep -s $pauseSeconds
            } 
        }
    }

    Write-Host "`n******************************"
    #AUDIT SNAPSHOT
    if ($options -eq $auditSnapshots){
        Write-Host "[INFO] Auditing all for snapshots"
        Get-VM $vmnames.VM | Get-Snapshot | Select-Object -Property VM,name | Export-Csv -Append -Path $snapshotfile -NoTypeInformation
    }

    #AUDIT CPU and MEMORY HotAdd
    if ($options -eq $auditHotAdd){
        Write-Host "[INFO] Auditing all for Hot-Add"
        Get-VM $vmnames.VM | Get-View | Select-Object Name, @{N="CpuHotAddEnabled";E={$_.Config.CpuHotAddEnabled}},@{N="MemoryHotAddEnabled";E={$_.Config.MemoryHotAddEnabled}} | Export-Csv -Append -Path $hotfile -NoTypeInformation
    }

    #AUDIT Running and Configured OS
    if ($options -eq $auditOSVersion){
        Write-Host "[INFO] Auditing all for Configured OS Version"
        Get-VM $vmnames.VM | Get-View -Property @("Name", "Config.GuestFullName", "Guest.GuestFullName") | Select-Object -Property Name, @{N="Configured OS";E={$_.Config.GuestFullName}}, @{N="Running OS";E={$_.Guest.GuestFullName}} | Export-Csv -Append -Path $guestOSfile -NoTypeInformation
    }

}

Read-Host -Prompt "Press Enter to exit"
