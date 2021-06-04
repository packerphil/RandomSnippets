<#
	.SYNOPSIS
		Script to force disable of power settings to prevent computer from sleeping or hibernating during OSD.
	
	.DESCRIPTION
		Script to force disable of power settings to prevent computer from sleeping or hibernating during OSD.
	
	.PARAMETER Setting
		(Optional) String parameter to tell the script what setting(s) to disable. Default is to disable all sleep/ hibernate for
		Standby, Hibernate, Monitor Sleep, and Disk Sleep.
	
	.PARAMETER PowerPlan
		(Optional) String parameter to tell the script which powerplan to set as the active plan. The default is 'High Performance'.
	
	.PARAMETER OSD
		(Optional) Switch parameter for use with OS Deployment Task Sequences. Enables verbose. Another option is to use the '-Verbose' parameter.
	
	.EXAMPLE
		.\Force-OSDDisableSleepStandbyHibernate.ps1 -Setting 'Disable Standby'
			Disables power Standby within the current power scheme
	
	.EXAMPLE
		.\Force-OSDDisableSleepStandbyHibernate.ps1 -Setting 'Disable Monitor Sleep' -PowerPlan 'High Performance'
			Sets the default Power Plan to be 'High Performance'. Disables the monitor sleep within the current power scheme
	
	.EXAMPLE
		.\Force-OSDDisableSleepStandbyHibernate.ps1 -Setting 'Disable Hibernate' -OSD
			Disables hibernation within the current power scheme. Turns on verbose output that is captured by ConfigMgr OSD task sequence
			in the 'smsts.log' file
	
	.EXAMPLE
		.\Force-OSDDisableSleepStandbyHibernate.ps1 -Setting 'Disable Disk Sleep' -PowerPlan 'High Performance' -OSD
			Sets the default Power Plan to be 'High Performance'. Turns on verbose output that
			is captured by ConfigMgr OSD task sequence in the 'smsts.log' file. 
			Disables disk sleep within the current power scheme.
	
	.NOTES
		===========================================================================
		Created on:   	6/4/2021
		Created by:   	Phil Pritchett
		Organization:   Catapult Systems
		Filename:       Force-OSDDisableSleepStandbyHibernate.ps1
		===========================================================================
#>
[CmdletBinding()]
param
(
	[Parameter(Mandatory = $false)]
	[ValidateSet ('Disable Standby', 'Disable Hibernate', 'Disable Monitor Sleep', 'Disable Disk Sleep', 'Disable All')]
	[String]$Setting = 'Disable All',
	[Parameter(Mandatory = $false)]
	[ValidateSet ('Ultimate Performance', 'High Performance', 'Balanced', 'Power Saver')]
	[String]$PowerPlan = 'High Performance',
	[Parameter(Mandatory = $false)]
	[switch]$OSD
)

Function Get-PowerConstants
{
	$powerConstants = @{ }
	PowerCfg.exe -ALIASES | Where-Object { $_ -match 'SCHEME_' } | ForEach-Object {
		$guid, $alias = ($_ -split '\s+', 2).Trim()
		$powerConstants[$guid] = $alias
	}
	Return $powerConstants
}

Function Get-PowerPlans
{
	# get a list of power schemes
	$powerSchemes = PowerCfg.exe -LIST | Where-Object { $_ -match '^Power Scheme' } | ForEach-Object {
		$guid = $_ -replace '.*GUID:\s*([-a-f0-9]+).*', '$1'
		$Constants = Get-PowerConstants
		[PsCustomObject]@{
			Name = $_.Trim("* ") -replace '.*\(([^)]+)\)$', '$1' # LOCALIZED !
			Alias = $Constants[$guid]
			Guid = $guid
			IsActive = $_ -match '\*$'
		}
	}
	Return $powerSchemes
}

If ($OSD)
{
	$VerbosePreference = 'Continue'
}

Write-Verbose -Message "****************** BEGIN SCRIPT ******************"
Write-Verbose -Message "** Script Mode Selection: '$($Setting)'"

Switch ($PowerPlan)
{
	'Ultimate Performance' {
		$UPPlanGUID = (Get-PowerPlans | ?{ $_.Name -eq $PowerPlan }).Guid
		If ($UPPlanGUID -eq $null)
		{
			$CopyPPlanGUID = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
			$UPlanArgs = @(
				"-duplicatescheme"
				"$($CopyPPlanGUID)"
			)
			[void](Start-Process -FilePath powercfg.exe -ArgumentList $UPlanArgs -WindowStyle Hidden -PassThru -wait)
			$PPlanGUID = (Get-PowerPlans | ?{ $_.Name -eq $PowerPlan }).Guid
		}
		Else
		{
			$PPlanGUID = $UPPlanGUID
		}
	}
	'High Performance'     {
		$PPlanGUID = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
	}
	'Balanced'             {
		$PPlanGUID = '381b4222-f694-41f0-9685-ff5bb260df2e'
	}
	'Power Saver'          {
		$PPlanGUID = 'a1841308-3541-4fab-bc81-f71556f20b4a'
	}
}

Write-Verbose -Message "** Setting Power Plan to '$($PowerPlan)'"
$PPlanArgs = @(
	"-setactive"
	"$($PPlanGUID)"
)
[void](Start-Process powercfg.exe -ArgumentList $PPlanArgs -WindowStyle Hidden -PassThru -wait)

$PwrSettings = @(
	'-standby-timeout-ac'
	'-standby-timeout-dc'
	'-hibernate-timeout-ac'
	'-hibernate-timeout-dc'
	'-monitor-timeout-ac'
	'-monitor-timeout-dc'
	'-disk-timeout-ac'
	'-disk-timeout-dc'
)

Switch ($Setting)
{
	'Disable Standby'       { $PSettings = $PwrSettings | ?{ $_ -like "*standby*" } }
	'Disable Hibernate'     { $PSettings = $PwrSettings | ?{ $_ -like "*hibernate*" } }
	'Disable Monitor Sleep' { $PSettings = $PwrSettings | ?{ $_ -like "*monitor*" } }
	'Disable Disk Sleep'    { $PSettings = $PwrSettings | ?{ $_ -like "*disk*" } }
	'Disable All'           { $PSettings = $PwrSettings }
}

Write-Verbose -Message "*** Power Sleep/Hibernate Settings to Disable: $($PSettings.Count)"

$i = 0
While ($i -lt $PSettings.Count)
{
	$Parts = $PSettings[$i].Split('-')
	$Area = ($Parts[1]).ToUpper()
	$SettingType = ($Parts[2]).ToUpper()
	$ConnectionType = ($Parts[3]).ToUpper()
	Switch ($ConnectionType)
	{
		'AC' { $Connection = "AC (Plugged In)" }
		'DC' { $Connection = "DC (On Battery)" }
	}
	Write-Verbose -Message "**** Setting Power Option #$($i + 1) - '$($Area) $($SettingType) $($Connection)' to '0' (disabled)"
	$PwrArgs = @(
		"/c"
		"-x"
		"$($PSettings[$i])"
		"0"
	)
	Write-Verbose -Message "***** Running Command-Line 'powercfg.exe $($PwrArgs[0]) $($PwrArgs[1]) $($PwrArgs[2]) $($PwrArgs[3])'"
	[void](Start-Process -FilePath powercfg.exe -ArgumentList $PwrArgs -WindowStyle Hidden -PassThru -wait)
	If ($i -eq ($PSettings.Count - 1))
	{
		Write-Verbose -Message "*** Power Sleep/Hibernate Settings Disabled: $($PSettings.Count)"
	}
	$i++
}
Write-Verbose -Message "** Scripted Power Settings Complete"
Write-Verbose -Message "******************* END SCRIPT *******************"
