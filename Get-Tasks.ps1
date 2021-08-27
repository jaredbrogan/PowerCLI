param([Parameter(Mandatory=$true)][string]$vCenter)
$vCenter = $vCenter.ToLower()

$serv = Connect-VIServer -Server $vCenter
$task = Get-Task -Server $serv -Status Running | Format-Table -AutoSize -GroupBy 'Start Time' Description, `
			@{N='Target';E={$_.ExtensionData.Info.EntityName}}, ` 
			@{N='Status';E={$_.State};alignment='left'}, ` 
			@{N='User';E={$_.Uid.split('\')[1].split('@')[0].ToUpper()}}, `
			@{N='% Complete';E={$_.PercentComplete}}, ` 
			@{N='vCenter';E={$_.ServerId.split('@')[1].split('.')[0]}}, ` 
			@{N='Start Time';E={$_.StartTime}}, ` 
			@{N='Finish Time';E={$_.FinishTime}}, ` 
			@{N='Expected Completion Time';E={$_.ExtensionData.Info.QueueTime}}

for ($num = 1 ; $num -le (60*30) ; $num++){
[console]::WindowWidth=($task | Measure-Object -Character | Select-Object -ExpandProperty Characters); [console]::WindowHeight=(($task | Measure-Object -Line | Select-Object -ExpandProperty Lines)+1); [console]::BufferWidth=[console]::WindowWidth
	cls
	$task
	Start-Sleep 5
}
