<#
	.SYNOPSIS
		Wrapper script to copy an ISO, download, and run the WIMWitch tool from @TheNotoriusDRR
	
	.DESCRIPTION
		This script will ask the user if an ISO file needs to be copied. By clicking 'Yes',
		the user will be prompted for the path of the ISO to be copied. If the ISO has already been copied,
		the script will continue to downloading and/ or launching the WIMWitch tool.
		If the user clicks 'No', the script will simply download and/ or launch the
		WIMWitch tool. By clicking 'Cancel', the script exits with a parting statement.
	
	.PARAMETER ISOPath
		(Optional) - Path to the ISO file to be copied into the working directories.
	
	.EXAMPLE
		PS C:\> .\Run-WIMWItch.ps1
			Runs the script with the default parameters. Giving you all the prompts needed prior to
			running WIMWitch.
	
	.EXAMPLE
		PS C:\> .\Run-WIMWItch.ps1 -ISOPath '\\MyServer\Share\Windows10.iso'
			Runs the script, and skips asking the user if an ISO needs to be copied. It will
			Check if the file has already been copied. If the ISO file hasn't been copied, it will copy it
			to the ISO working folder.
	
	.NOTES
		Version 1.0 - Phil Pritchett - Initial version.
#>
[CmdletBinding()]
param
(
	[Parameter(Mandatory = $false)]
	[string]$ISOPath
)

###############################################
# Function to output information to the screen as the script runs
# Mostly borrowed from @TheNotoriousDRR
###############################################
Function Output-ProcessInfo
{
	Param (
		[Parameter(
				   Mandatory = $true,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0
				   )]
		[string]$Data,
		[Parameter(
				   Mandatory = $true,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 1
				   )]
		[validateset('Information', 'Warning', 'Error')]
		[string]$Class
		
	)
	
	$HostString = "$((Get-Date).GetDateTimeFormats()[71]) - $($Class.ToUpper())  -  $Data"
	
	Switch ($Class)
	{
		'Information'
		{
			Write-Host $HostString -ForegroundColor Gray
		}
		
		'Warning'
		{
			Write-Host $HostString -ForegroundColor Yellow
		}
		
		'Error'
		{
			Write-Host $HostString -ForegroundColor Red -BackgroundColor Yellow
		}
		Default { }
	}
}

###############################################
# Function to ask user if ISO file copy is needed
###############################################
Function Ask-ISOImport
{
	Output-ProcessInfo -Class Information -Data "Asking if ISO needs to be imported"
	$wShell = New-Object -ComObject WScript.Shell
	$InputPrompt = $wShell.Popup('Do you need to copy an ISO file?', 0, 'Copy ISO File?', 32 + 3)
	Return $InputPrompt
}

###############################################
# Function to get ISO and ISO File
###############################################
Function Get-WWISO
{
	###############################################
	# If the path to the ISO file was not
	# specified at the command-line,
	# open file browser to find and select ISO file
	###############################################
	If (($ISOPath -eq $null) -or ($ISOPath -eq ''))
	{
		Output-ProcessInfo -Class Warning -Data "Path to ISO file not specified at command-line. Opening file browser."
		Add-Type -AssemblyName System.Windows.Forms
		$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
			InitialDirectory = "$($env:SystemDrive)\"
			Filter		     = 'Disc Image (*.iso)|*.iso'
			Title		     = 'Select Windows ISO to copy'
		}
		$null = $FileBrowser.ShowDialog()
		$ISOPath = $FileBrowser.FileName
		If ($ISOPath -eq '')
		{
			Output-ProcessInfo -Class Error -Data "ISO file not selected."
			Throw "ERROR: ISO file not selected."
			Break;
		}
		Else
		{
			###############################################
			# Call function to get the ISO file and copy it locally
			###############################################
			Output-ProcessInfo -Class Information -Data "Getting selected ISO file and copying it locally"
			Copy-ISOFile -ISOPath $ISOPath
		}
	}
	Else
	{
		###############################################
		# Call function to get the ISO file and copy it locally
		###############################################
		Output-ProcessInfo -Class Information -Data "Getting selected ISO file and copying it locally"
		Copy-ISOFile -ISOPath $ISOPath
	}
}


###############################################
# Function to launch WIMWitch tool
###############################################
Function Launch-WIMWitch
{
	###############################################
	# Check if the WIMWitch tool is downloaded.
	# Run the tool if present, otherwise download it and run it.
	###############################################
	Output-ProcessInfo -Class Information -Data "Checking if 'WIMWitch' tool has been previously downloaded"
	$WWScript = "$($WWScriptDir)\WIMWitch.ps1"
	If (-not (Test-Path -Path $WWScript))
	{
		Output-ProcessInfo -Class Warning -Data "'WIMWitch' NOT found. Downloading."
		Output-ProcessInfo -Class Information -Data "Downloading WIMWitch Tool Script to '$($WWScriptDir)'"
		[void](Save-Script -Name 'WIMWitch' -Path $WWScriptDir -Force)
		If (Test-Path -Path $WWScript)
		{
			Output-ProcessInfo -Class Information -Data "WIMWitch Tool Script successfully downloaded."
			Output-ProcessInfo -Class Information -Data "Launching WIMWitch..."
			Start-Sleep -Seconds 5
			Set-Location -Path $WWScriptDir
			Invoke-Expression -Command $WWScript
		}
		Else
		{
			Output-ProcessInfo -Class Error -Data "WIMWitch Tool Script download FAILED."
			Throw "ERROR: WIMWitch Tool Script download FAILED."
			Break;
		}
	}
	Else
	{
		Output-ProcessInfo -Class Information -Data "WIMWitch Tool Script already downloaded."
		Output-ProcessInfo -Class Information -Data "Launching WIMWitch..."
		Start-Sleep -Seconds 5
		Set-Location -Path $WWScriptDir
		Invoke-Expression -Command $WWScript
	}
}


###############################################
# Function to copy selected ISO file locally
###############################################
Function Copy-ISOFile ($ISOPath)
{
	Function CopyFile
	{
		Output-ProcessInfo -Class Information -Data "Copying ISO File to '$($ISODir)'"
		[void](Get-Item -Path "$($ISOPath)" | Copy-Item -Destination $ISODir -Force)
		If (Test-Path -Path "$($ISODir)\$($ISOName)")
		{
			$CopySuccess = $true
			Output-ProcessInfo -Class Information -Data "'$($ISOName)' successfully copied to '$($ISODir)'"
		}
		Else
		{
			$CopySuccess = $false
			Output-ProcessInfo -Class Error -Data "'$($ISOName)' copy UNSUCCESSFUL to '$($ISODir)'"
			Throw "ERROR: '$($ISOName)' copy UNSUCCESSFUL to '$($ISODir)'"
		}
		$CopyFileRow = [pscustomobject]@{
			'ISO_SourceFolder' = ($SourceISO.Directory).FullName
			'ISO_DestinationFolder' = $ISODir
			'ISO_FileName'	   = $ISOName
			'ISO_CopySuccess'  = $CopySuccess
		}
		Return $CopyFileRow
	}
	$SourceISO = Get-Item -Path "$($ISOPath)"
	$ISOName = $SourceISO.Name
	Output-ProcessInfo -Class Information -Data "Checking if Directory '$($ISODir)' exists"
	If (-not (Test-Path -Path $ISODir -WarningAction SilentlyContinue -ErrorAction SilentlyContinue))
	{
		Output-ProcessInfo -Class Warning -Data "Directory '$($ISODir)' does not exist"
		Output-ProcessInfo -Class Information -Data "Creating Directory '$($ISODir)'"
		[void](New-Item -Path $CurrentPath -Name 'ISO' -ItemType directory -Force)
		If (Test-Path -Path $ISODir)
		{
			Output-ProcessInfo -Class Information -Data "Directory '$($ISODir)' created successfully"
			$row = CopyFile
		}
		Else
		{
			Output-ProcessInfo -Class Error -Data "Directory '$($ISODir)' NOT created successfully"
			Throw "ERROR: Directory '$($ISODir)' NOT created successfully"
		}
		
	}
	Else
	{
		Output-ProcessInfo -Class Information -Data "Directory '$($ISODir)' already exists"
		Output-ProcessInfo -Class Information -Data "Checking if '$($ISOPath.Split('\')[$_.Count - 1])' has already been copied..."
		$ISOFiles = Get-ChildItem -Path $ISODir -Filter "*.iso" -Recurse
		If ($ISOFiles.Count -ne 0)
		{
			Foreach ($ISO in $ISOFiles) {
				If ($ISO.Name -eq $ISOName)
				{
					$DirPath = ($ISO.Directory).FullName
					Output-ProcessInfo -Class Information -Data "ISO File already copied to '$($DirPath)'"
					$row = [pscustomobject]@{
						'ISO_FolderPath' = $DirPath
						'ISO_FileName'   = $ISO.Name
					}
				}
				Else
				{
					$row = CopyFile
				}
			}
		}
		Else
		{
			$row = CopyFile
		}
	}
	
	Return ($row | FL)
}

###############################################
# Set security protocol to TLS 1.2 for
# Downloads from repositories
###############################################
Output-ProcessInfo -Class Information -Data "Setting Network Security Protocol to TLS 1.2"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
If (([Net.ServicePointManager]::SecurityProtocol) -eq 'Tls12')
{
	Output-ProcessInfo -Class Information -Data "Network Security Protocol successfully set to TLS 1.2"
}
Else
{
	Output-ProcessInfo -Class Error -Data "Set Network Security Protocol Unsuccessful"
	Throw "ERROR: Set Network Security Protocol Unsuccessful"
	Break;
}

###############################################
# Get path of current script, then
# define/ create base directories
###############################################
Output-ProcessInfo -Class Information -Data "Getting path of running script"
$CurrentPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
Output-ProcessInfo -Class Information -Data "Current Path is '$($CurrentPath)', setting command location..."
Set-Location -Path $CurrentPath
$WWScriptDir = "$($CurrentPath)\WIMWitch"
$ISODir = "$($CurrentPath)\ISO"
If (-not (Test-Path -Path $WWScriptDir -WarningAction SilentlyContinue -ErrorAction SilentlyContinue))
{
	Output-ProcessInfo -Class Information -Data "Creating Directory '$($WWScriptDir)'"
	[void](New-Item -Path $CurrentPath -Name 'WIMWitch' -ItemType directory -Force)
	If (Test-Path -Path $WWScriptDir)
	{
		Output-ProcessInfo -Class Information -Data "Directory '$($WWScriptDir)' created successfully."
	}
	Else
	{
		Output-ProcessInfo -Class Error -Data "Directory '$($WWScriptDir)' NOT CREATED."
		Throw "ERROR: Directory '$($WWScriptDir)' NOT CREATED."
		Break;
	}
}
Else
{
	Output-ProcessInfo -Class Information -Data "Directory '$($WWScriptDir)' already exists."
}

###############################################
# If ISOPath is not specified at the command-line.
# Ask User if ISO needs to be copied, if not
# Run WIMWitch Tool or exit. Otherwise, copy the
# ISO and run WIMWitch
###############################################
If (($ISOPath -eq $null) -or ($ISOPath -eq ''))
{
	$Question = Ask-ISOImport
	Switch ($Question)
	{
		2 # 2 = Cancel or 'X'
		{
			Output-ProcessInfo -Class Information -Data "Shop smart, shop 'S-Mart'!!"
		}
		
		6 # 6 = Yes
		{
			Get-WWISO
			Launch-WIMWitch
		}
		
		7 # 7 = No
		{
			Launch-WIMWitch
		}
	}
}
Else
{
	Get-WWISO
	Launch-WIMWitch
}

###############################################
# Set location back to path of running script
###############################################
Set-Location -Path $CurrentPath
