<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
## Suppress PSScriptAnalyzer errors for not using declared variables during AppVeyor build
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "", Justification="Suppresses AppVeyor errors on informational variables below")]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch { Write-Error "Failed to set the execution policy to Bypass for this process." }

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = 'Autodesk'
	[string]$appName = 'AutoCAD'
	[string]$appVersion = '2020'
	[string]$appArch = 'x64'
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.0.0'
	[string]$appScriptDate = '6/18/2019'
	[string]$appScriptAuthor = 'Steve Patterson'
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = ''

	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.6.9'
	[string]$deployAppScriptDate = '02/12/2017'
	[hashtable]$deployAppScriptParameters = $psBoundParameters

	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

	If ($deploymentType -ine 'Uninstall') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
		Show-InstallationWelcome -CloseApps 'acad' -CheckDiskSpace -PersistPrompt

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Installation tasks here>
		## Uninstall AutoCAD 2019
		If (Test-Path -LiteralPath (Join-Path -Path $envSystemDrive -ChildPath "$envProgramFiles\Autodesk\AutoCAD 2019\acad.exe") -PathType 'Leaf') {
			Write-Log -Message 'AutoCAD 2019 Products will be uninstalled.' -Source $deployAppScriptFriendlyName
		# Uninstall Autodesk Material Library 2019
		 Execute-MSI -Action Uninstall -Path '{8F69EE2C-DC34-4746-9B47-7511147BD4B0}'
		# Uninstall Autodesk Material Library Base Resolution Image Library 2019
		 Execute-MSI -Action Uninstall -Path '{3AAA4C1B-51DA-487D-81A3-4234DBB9A8F9}'


		# Uninstall AutoCAD 2019
		Execute-MSI -Action Uninstall -Path '{28B89EEF-2001-0000-0102-CF3F3A09B77D}'
		# Uninstall AutoCAD 2019 Language Pack - English
		Execute-MSI -Action Uninstall -Path '{28B89EEF-2001-0409-1102-CF3F3A09B77D}'
		# Uninstall ACA & MEP 2019 Object Enabler
		Execute-MSI -Action Uninstall -Path '{28B89EEF-2004-0000-5102-CF3F3A09B77D}'
		# Uninstall ACAD Private (2019)
		Execute-MSI -Action Uninstall -Path '{28B89EEF-2001-0000-3102-CF3F3A09B77D}'
		# Uninstall AutoCAD 2019 - English
		Execute-MSI -Action Uninstall -Path '{28B89EEF-2001-0409-2102-CF3F3A09B77D}'
		# Uninstall AutoCAD Performance Feedback Tool 1.3.0
		Execute-MSI -Action Uninstall -Path '{448BC38C-2654-48CD-BB43-F59A37854A3E}'
		# Uninstall License Service (x64) - 7.1.4
		Execute-MSI -Action Uninstall -Path '{F53D6D10-7A75-4A39-8C53-A3D855C7C50A}'

		# Uninstall Autodesk Civil 3D 2019
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2000-0000-0102-CF3F3A09B77D}'
		# Uninstall Autodesk Civil 3D 2019 Language Pack - English
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2000-0409-1102-CF3F3A09B77D}'
		# Uninstall AutoCAD Architecture 2019 Shared
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2004-0000-4102-CF3F3A09B77D}'
		# Uninstall AutoCAD Architecture 2019 Language Shared - English
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2004-0409-4102-CF3F3A09B77D}'
		# Uninstall Autodesk AutoCAD Map 3D 2019 Core
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2002-0000-0102-CF3F3A09B77D}'
		# Uninstall Autodesk AutoCAD Map 3D 2019 Language Pack - English
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2002-0409-1102-CF3F3A09B77D}'
		# Uninstall Autodesk Vehicle Tracking 2019 (64 bit) Core
		# Execute-MSI -Action Uninstall -Path '{F0089F74-0ED1-47CA-BEC0-53F1ACAEC68A}'
		# Uninstall Autodesk Civil 3D 2019 Private Pack
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2000-0000-3102-CF3F3A09B77D}'
		# Uninstall Autodesk Civil 3D 2019 - English
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2000-0409-2102-CF3F3A09B77D}'
		# Uninstall Autodesk Rail Module Layout 2019
		# Execute-MSI -Action Uninstall -Path '{F0D81F9D-6F82-43B9-ABF5-33947F5437DA}'
		# Uninstall Autodesk Storm and Sanitary Analysis 2019 x64 Plug-in
		# Execute-MSI -Action Uninstall -Path '{58E36D07-2322-0000-8518-C854F44898ED}'
		# Uninstall Autodesk Subassembly Composer 2019
		# Execute-MSI -Action Uninstall -Path '{33CFED50-0FAD-442A-84FA-4D26DB59E332}'

		# Uninstall AutoCAD Electrical 2019
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2007-0000-0102-CF3F3A09B77D}'
		# Uninstall AutoCAD Electrical 2019 Language Pack - English
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2007-0409-1102-CF3F3A09B77D}'
		# Uninstall ACADE Private
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2007-0000-3102-CF3F3A09B77D}'
		# Uninstall AutoCAD Electrical 2019 Content Pack
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2007-0000-5102-CF3F3A09B77D}'
		# Uninstall AutoCAD Electrical 2019 Content Language Pack - English
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2007-0409-6102-CF3F3A09B77D}'
		# Uninstall AutoCAD Electrical 2019 - English
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2007-0409-2102-CF3F3A09B77D}'

		# Uninstall AutoCAD Mechanical 2019
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2005-0000-0102-CF3F3A09B77D}'
		# Uninstall AutoCAD Mechanical 2019 Language Pack - English
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2005-0409-1102-CF3F3A09B77D}'
		# Uninstall ACM Private
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2005-0000-3102-CF3F3A09B77D}'
		# Uninstall AutoCAD Mechanical 2018 - English
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2005-0409-2102-CF3F3A09B77D}'

		# Uninstall Revit 2019
		# Execute-MSI -Action Uninstall -Path '{7346B4A0-1900-0510-0000-705C0D862004}'
		# Uninstall Revit Content Libraries 2019
		# Execute-MSI -Action Uninstall -Path '{941030D0-1900-0410-0000-818BB38A95FC}'
		# Uninstall Autodesk Collaboration for Revit 2019
		# Execute-MSI -Action Uninstall -Path '{AA384BE4-1901-0010-0000-97E7D7D00B17}'
		# Uninstall Personal Accelerator for Revit
		# Execute-MSI -Action Uninstall -Path '{7C317DB0-F399-4024-A289-92CF4B6FB256}'
		# Uninstall Batch Print for Autodesk Revit 2019
		# Execute-MSI -Action Uninstall -Path '{82AF00E4-1901-0010-0000-FCE0F87063F9}'
		# Uninstall eTransmit for Autodesk Revit 2019
		# Execute-MSI -Action Uninstall -Path '{4477F08B-1901-0010-0000-9A09D834DFF5}'
		# Uninstall Autodesk Revit Model Review 2019
		# Execute-MSI -Action Uninstall -Path '{715812E8-1901-0010-0000-BBB894911B46}'
		# Uninstall Worksharing Monitor for Autodesk Revit 2019
		# Execute-MSI -Action Uninstall -Path '{5063E738-1901-0010-0000-7B7B9AB0B696}'
		# Uninstall Autodesk Material Library Low Resolution Image Library 2019
		# Execute-MSI -Action Uninstall -Path '{77F779B8-3262-4014-97E9-36D6933A1904}'
		# Uninstall Autodesk Advanced Material Library Base Resolution Image Library 2019
		# Execute-MSI -Action Uninstall -Path '{105181A1-013C-4EE7-A368-999FD7ED950A}'
		# Uninstall Autodesk Advanced Material Library Low Resolution Image Library 2019
		# Execute-MSI -Action Uninstall -Path '{ACC0DD09-7E20-4792-87D5-BDBE40206584}'
		# Uninstall IronPython 2.7.3
		# Execute-MSI -Action Uninstall -Path '{1EBADAEA-1A0F-40E3-848C-0DD8C5E5A10D}'
		# Uninstall Dynamo Core 1.3.3
		# Execute-MSI -Action Uninstall -Path '{F1AA809A-3D47-4FB9-8854-93E070C66A20}'
		# Uninstall Dynamo Revit 1.3.3
		# Execute-MSI -Action Uninstall -Path '{DE076F37-60CA-4BDC-A5A3-B300DEA4358C}'
		# Uninstall FormIt Converter for Revit 2019
		# Execute-MSI -Action Uninstall -Path '{5E47699C-B0DE-443F-92AE-1D1334499D5E}'
		# Uninstall Autodesk Revit 2019 MEP Fabrication Configuration - Imperial
		# Execute-MSI -Action Uninstall -Path '{7B1D0D58-E2A9-400B-9663-86FD56CB44B9}'
		# Uninstall Autodesk Revit 2019 MEP Fabrication Configuration - Metric
		# Execute-MSI -Action Uninstall -Path '{8E6AEB11-ECE7-475A-BB7D-1D6719B2F8BA}'
		# Uninstall Autodesk Material Library Medium Resolution Image Library 2019
		# Execute-MSI -Action Uninstall -Path '{2E819775-E94C-42CC-9C5D-ABB2ADABC7C2}'
		# Uninstall Autodesk Advanced Material Library Medium Resolution Image Library 2019
		# Execute-MSI -Action Uninstall -Path '{078698AF-8BB1-4631-86D0-D91FEE147256}'
}


		## Uninstall AutoCAD 2018
		If (Test-Path -LiteralPath (Join-Path -Path $envSystemDrive -ChildPath "$envProgramFiles\Autodesk\AutoCAD 2018\acad.exe") -PathType 'Leaf') {
			Write-Log -Message 'AutoCAD Products will be uninstalled.' -Source $deployAppScriptFriendlyName
			#Uninstall all AutoCAD 2018 Products
			# Uninstall Autodesk Material Library 2018
			Execute-MSI -Action Uninstall -Path '{7847611E-92E9-4917-B395-71C91D523104}'
			# Uninstall Autodesk Material Library Base Resolution Image Library 2018
			Execute-MSI -Action Uninstall -Path '{FCDED119-A969-4E48-8A32-D21AD6B03253}'
			# Uninstall Autodesk Advanced Material Library Image Library 2018
			Execute-MSI -Action Uninstall -Path '{177AD7F6-9C77-4E50-BA53-B7259C5F282D}'

			# Uninstall AutoCAD 2018
			Execute-MSI -Action Uninstall -Path '{28B89EEF-1001-0000-0102-CF3F3A09B77D}'
			# Uninstall AutoCAD 2018 Language Pack - English
			Execute-MSI -Action Uninstall -Path '{28B89EEF-1001-0409-1102-CF3F3A09B77D}'
			# Uninstall ACA & MEP 2018 Object Enabler
			Execute-MSI -Action Uninstall -Path '{28B89EEF-1004-0000-5102-CF3F3A09B77D}'
			# Uninstall ACAD Private
			Execute-MSI -Action Uninstall -Path '{28B89EEF-1001-0000-3102-CF3F3A09B77D}'
			# Uninstall AutoCAD 2018 - English
			Execute-MSI -Action Uninstall -Path '{28B89EEF-1001-0409-2102-CF3F3A09B77D}'

			# Uninstall Autodesk AutoCAD Civil 3D 2018
			# Execute-MSI -Action Uninstall -Path '{28B89EEF-1000-0000-0102-CF3F3A09B77D}'
			# Uninstall Autodesk AutoCAD Civil 3D 2018 Language Pack - English
			# Execute-MSI -Action Uninstall -Path '{28B89EEF-1000-0409-1102-CF3F3A09B77D}'
			# Uninstall AutoCAD Architecture 2018 Shared
			# Execute-MSI -Action Uninstall -Path '{28B89EEF-1004-0000-4102-CF3F3A09B77D}'
			# Uninstall AutoCAD Architecture 2018 Language Shared - English
			# Execute-MSI -Action Uninstall -Path '{28B89EEF-1004-0409-4102-CF3F3A09B77D}'
			# Uninstall Autodesk AutoCAD Map 3D 2018 Core
			# Execute-MSI -Action Uninstall -Path '{28B89EEF-1002-0000-0102-CF3F3A09B77D}'
			# Uninstall Autodesk AutoCAD Map 3D 2018 Language Pack - English
			# Execute-MSI -Action Uninstall -Path '{28B89EEF-1002-0409-1102-CF3F3A09B77D}'
			# Uninstall Autodesk Vehicle Tracking 2018 (64 bit) Core
			# Execute-MSI -Action Uninstall -Path '{9BB641F3-24B1-427E-A850-1C02157219EC}'
			# Uninstall Autodesk AutoCAD Civil 3D 2018 Private Pack
			# Execute-MSI -Action Uninstall -Path '{28B89EEF-1000-0000-3102-CF3F3A09B77D}'
			# Uninstall Autodesk AutoCAD Civil 3D 2018 - English
			# Execute-MSI -Action Uninstall -Path '{28B89EEF-1000-0409-2102-CF3F3A09B77D}'

			# Uninstall AutoCAD Electrical 2018
			# Execute-MSI -Action Uninstall -Path '{28B89EEF-1007-0000-0102-CF3F3A09B77D}'
			# Uninstall AutoCAD Electrical 2018 Language Pack - English
			# Execute-MSI -Action Uninstall -Path '{28B89EEF-1007-0409-1102-CF3F3A09B77D}'
			# Uninstall ACADE Private
			# Execute-MSI -Action Uninstall -Path '{28B89EEF-1007-0000-3102-CF3F3A09B77D}'
			# Uninstall AutoCAD Electrical 2018 Content Pack
			# Execute-MSI -Action Uninstall -Path '{28B89EEF-1007-0000-5102-CF3F3A09B77D}'
			# Uninstall AutoCAD Electrical 2018 Content Language Pack - English
			# Execute-MSI -Action Uninstall -Path '{28B89EEF-1007-0409-6102-CF3F3A09B77D}'
			# Uninstall AutoCAD Electrical 2018 - English
			# Execute-MSI -Action Uninstall -Path '{28B89EEF-1007-0409-2102-CF3F3A09B77D}'

			# Uninstall AutoCAD Mechanical 2018
			# Execute-MSI -Action Uninstall -Path '{28B89EEF-1005-0000-0102-CF3F3A09B77D}'
			# Uninstall AutoCAD Mechanical 2018 Language Pack - English
			# Execute-MSI -Action Uninstall -Path '{28B89EEF-1005-0409-1102-CF3F3A09B77D}'
			# Uninstall ACM Private
			# Execute-MSI -Action Uninstall -Path '{28B89EEF-1005-0000-3102-CF3F3A09B77D}'
			# Uninstall AutoCAD Mechanical 2018 - English
			# Execute-MSI -Action Uninstall -Path '{28B89EEF-1005-0409-2102-CF3F3A09B77D}'

			# Uninstall Revit 2018
			# Execute-MSI -Action Uninstall -Path '{7346B4A0-1800-0510-0000-705C0D862004}'
			# Uninstall Autodesk Collaboration for Revit 2018
			# Execute-MSI -Action Uninstall -Path '{AA384BE4-1800-0010-0000-97E7D7D00B17}'
			# Uninstall Personal Accelerator for Revit
			# Execute-MSI -Action Uninstall -Path '{7C317DB0-F399-4024-A289-92CF4B6FB256}'
			# Uninstall Batch Print for Autodesk Revit 2018
			# Execute-MSI -Action Uninstall -Path '{82AF00E4-1800-0010-0000-FCE0F87063F9}'
			# Uninstall eTransmit for Autodesk Revit 2018
			# Execute-MSI -Action Uninstall -Path '{4477F08B-1800-0010-0000-9A09D834DFF5}'
			# Uninstall Autodesk Revit Model Review 2018
			# Execute-MSI -Action Uninstall -Path '{715812E8-1800-0010-0000-BBB894911B46}'
			# Uninstall Worksharing Monitor for Autodesk Revit 2018
			# Execute-MSI -Action Uninstall -Path '{5063E738-1800-0010-0000-7B7B9AB0B696}'
			# Uninstall Dynamo Revit 1.2.2
			# Execute-MSI -Action Uninstall -Path '{0FF47E28-76A5-44BA-8EEF-58824252F528}'
		}

		##*===============================================
		##* INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}

		## <Perform Installation tasks here>

				# Install AutoCAD 2020
		Execute-Process -Path "$dirFiles\Img\Setup.exe" -Parameters '/W /Q /I AutoCAD2020.ini' -WindowStyle 'Hidden' -PassThru
				# Install AutoCAD Civil 3D 2019
		#Execute-Process -Path "$dirFiles\Img\Setup.exe" -Parameters '/W /Q /I Civil3D2019.ini' -WindowStyle 'Hidden' -PassThru
				# Install AutoCAD Electrical 2019
		#Execute-Process -Path "$dirFiles\Img\Setup.exe" -Parameters '/W /Q /I AutoCAD2019Electrical.ini' -WindowStyle 'Hidden' -PassThru
				# Install AutoCAD Mechanical 2019
		#Execute-Process -Path "$dirFiles\Img\Setup.exe" -Parameters '/W /Q /I AutoCAD2019Mechanical.ini' -WindowStyle 'Hidden' -PassThru
				# Install Revit 2019
		#Execute-Process -Path "$dirFiles\Img\Setup.exe" -Parameters '/W /Q /I Revit2019.ini' -WindowStyle 'Hidden' -PassThru


		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		## <Perform Post-Installation tasks here>

		## Display a message at the end of the install
		If (-not $useDefaultMsi) {Show-InstallationPrompt -Message ‘'$appVendor' '$appName' '$appVersion' has been Sucessfully Installed.’ -ButtonRightText ‘OK’ -Icon Information -NoWait}
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'

		## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
		Show-InstallationWelcome -CloseApps 'acad' -CloseAppsCountdown 60

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Uninstallation tasks here>


		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'

		## Handle Zero-Config MSI Uninstallations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}

		# <Perform Uninstallation tasks here>

		# Uninstall Autodesk Material Library 2020
		Execute-MSI -Action Uninstall -Path '{B9312A51-41B5-479D-9F72-E7448A2D89AF}'
		# Uninstall Autodesk Material Library Base Resolution Image Library 2020
		Execute-MSI -Action Uninstall -Path '{0E976988-E753-4C81-BD96-434CE305B176}'
		# Uninstall Autodesk Save to Web and Mobile
		Execute-MSI -Action Uninstall -Path '{26FB18F7-B553-430D-94F6-C2389A91235F}'
		# Uninstall Autodesk Single Sign On Component
		Execute-MSI -Action Uninstall -Path '{E3807FC8-DD0A-4D6D-89E9-EAADE00C845C}'
		# Uninstall AutoCAD 2020
		Execute-MSI -Action Uninstall -Path '{28B89EEF-3001-0000-0102-CF3F3A09B77D}'
		# Uninstall AutoCAD 2020 Language Pack - English
		Execute-MSI -Action Uninstall -Path '{28B89EEF-3001-0409-1102-CF3F3A09B77D}'
		# Uninstall ACA & MEP 2020 Object Enabler
		Execute-MSI -Action Uninstall -Path '{28B89EEF-3004-0000-5102-CF3F3A09B77D}'
		# Uninstall ACAD Private (2020)
		Execute-MSI -Action Uninstall -Path '{28B89EEF-3001-0000-3102-CF3F3A09B77D}'
		# Uninstall AutoCAD 2020 - English
		Execute-MSI -Action Uninstall -Path '{28B89EEF-3001-0409-2102-CF3F3A09B77D}'
		# Uninstall Autodesk Genuine Service
		Execute-MSI -Action Uninstall -Path '{317D67F2-9027-4E85-9ED1-ADF4D765AE02}'

		# Uninstall Autodesk Civil 3D 2019
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2000-0000-0102-CF3F3A09B77D}'
		# Uninstall Autodesk Civil 3D 2019 Language Pack - English
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2000-0409-1102-CF3F3A09B77D}'
		# Uninstall AutoCAD Architecture 2019 Shared
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2004-0000-4102-CF3F3A09B77D}'
		# Uninstall AutoCAD Architecture 2019 Language Shared - English
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2004-0409-4102-CF3F3A09B77D}'
		# Uninstall Autodesk AutoCAD Map 3D 2019 Core
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2002-0000-0102-CF3F3A09B77D}'
		# Uninstall Autodesk AutoCAD Map 3D 2019 Language Pack - English
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2002-0409-1102-CF3F3A09B77D}'
		# Uninstall Autodesk Vehicle Tracking 2019 (64 bit) Core
		# Execute-MSI -Action Uninstall -Path '{F0089F74-0ED1-47CA-BEC0-53F1ACAEC68A}'
		# Uninstall Autodesk Civil 3D 2019 Private Pack
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2000-0000-3102-CF3F3A09B77D}'
		# Uninstall Autodesk Civil 3D 2019 - English
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2000-0409-2102-CF3F3A09B77D}'
		# Uninstall Autodesk Rail Module Layout 2019
		# Execute-MSI -Action Uninstall -Path '{F0D81F9D-6F82-43B9-ABF5-33947F5437DA}'
		# Uninstall Autodesk Storm and Sanitary Analysis 2019 x64 Plug-in
		# Execute-MSI -Action Uninstall -Path '{58E36D07-2322-0000-8518-C854F44898ED}'
		# Uninstall Autodesk Subassembly Composer 2019
		# Execute-MSI -Action Uninstall -Path '{33CFED50-0FAD-442A-84FA-4D26DB59E332}'

		# Uninstall AutoCAD Electrical 2019
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2007-0000-0102-CF3F3A09B77D}'
		# Uninstall AutoCAD Electrical 2019 Language Pack - English
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2007-0409-1102-CF3F3A09B77D}'
		# Uninstall ACADE Private
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2007-0000-3102-CF3F3A09B77D}'
		# Uninstall AutoCAD Electrical 2019 Content Pack
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2007-0000-5102-CF3F3A09B77D}'
		# Uninstall AutoCAD Electrical 2019 Content Language Pack - English
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2007-0409-6102-CF3F3A09B77D}'
		# Uninstall AutoCAD Electrical 2019 - English
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2007-0409-2102-CF3F3A09B77D}'

		# Uninstall AutoCAD Mechanical 2019
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2005-0000-0102-CF3F3A09B77D}'
		# Uninstall AutoCAD Mechanical 2019 Language Pack - English
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2005-0409-1102-CF3F3A09B77D}'
		# Uninstall ACM Private
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2005-0000-3102-CF3F3A09B77D}'
		# Uninstall AutoCAD Mechanical 2018 - English
		# Execute-MSI -Action Uninstall -Path '{28B89EEF-2005-0409-2102-CF3F3A09B77D}'

		# Uninstall Revit 2019
		# Execute-MSI -Action Uninstall -Path '{7346B4A0-1900-0510-0000-705C0D862004}'
		# Uninstall Revit Content Libraries 2019
		# Execute-MSI -Action Uninstall -Path '{941030D0-1900-0410-0000-818BB38A95FC}'
		# Uninstall Autodesk Collaboration for Revit 2019
		# Execute-MSI -Action Uninstall -Path '{AA384BE4-1901-0010-0000-97E7D7D00B17}'
		# Uninstall Personal Accelerator for Revit
		# Execute-MSI -Action Uninstall -Path '{7C317DB0-F399-4024-A289-92CF4B6FB256}'
		# Uninstall Batch Print for Autodesk Revit 2019
		# Execute-MSI -Action Uninstall -Path '{82AF00E4-1901-0010-0000-FCE0F87063F9}'
		# Uninstall eTransmit for Autodesk Revit 2019
		# Execute-MSI -Action Uninstall -Path '{4477F08B-1901-0010-0000-9A09D834DFF5}'
		# Uninstall Autodesk Revit Model Review 2019
		# Execute-MSI -Action Uninstall -Path '{715812E8-1901-0010-0000-BBB894911B46}'
		# Uninstall Worksharing Monitor for Autodesk Revit 2019
		# Execute-MSI -Action Uninstall -Path '{5063E738-1901-0010-0000-7B7B9AB0B696}'
		# Uninstall Autodesk Material Library Low Resolution Image Library 2019
		# Execute-MSI -Action Uninstall -Path '{77F779B8-3262-4014-97E9-36D6933A1904}'
		# Uninstall Autodesk Advanced Material Library Base Resolution Image Library 2019
		# Execute-MSI -Action Uninstall -Path '{105181A1-013C-4EE7-A368-999FD7ED950A}'
		# Uninstall Autodesk Advanced Material Library Low Resolution Image Library 2019
		# Execute-MSI -Action Uninstall -Path '{ACC0DD09-7E20-4792-87D5-BDBE40206584}'
		# Uninstall IronPython 2.7.3
		# Execute-MSI -Action Uninstall -Path '{1EBADAEA-1A0F-40E3-848C-0DD8C5E5A10D}'
		# Uninstall Dynamo Core 1.3.3
		# Execute-MSI -Action Uninstall -Path '{F1AA809A-3D47-4FB9-8854-93E070C66A20}'
		# Uninstall Dynamo Revit 1.3.3
		# Execute-MSI -Action Uninstall -Path '{DE076F37-60CA-4BDC-A5A3-B300DEA4358C}'
		# Uninstall FormIt Converter for Revit 2019
		# Execute-MSI -Action Uninstall -Path '{5E47699C-B0DE-443F-92AE-1D1334499D5E}'
		# Uninstall Autodesk Revit 2019 MEP Fabrication Configuration - Imperial
		# Execute-MSI -Action Uninstall -Path '{7B1D0D58-E2A9-400B-9663-86FD56CB44B9}'
		# Uninstall Autodesk Revit 2019 MEP Fabrication Configuration - Metric
		# Execute-MSI -Action Uninstall -Path '{8E6AEB11-ECE7-475A-BB7D-1D6719B2F8BA}'
		# Uninstall Autodesk Material Library Medium Resolution Image Library 2019
		# Execute-MSI -Action Uninstall -Path '{2E819775-E94C-42CC-9C5D-ABB2ADABC7C2}'
		# Uninstall Autodesk Advanced Material Library Medium Resolution Image Library 2019
		# Execute-MSI -Action Uninstall -Path '{078698AF-8BB1-4631-86D0-D91FEE147256}'



		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'

		## <Perform Post-Uninstallation tasks here>


	}

	##*===============================================
	##* END SCRIPT BODY
	##*===============================================


	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}

# SIG # Begin signature block
# MIIZ7wYJKoZIhvcNAQcCoIIZ4DCCGdwCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCfeJX4p7mkXZjx
# zo9kltWnKGpjAHqeoPAQPzT9jLIEnKCCFFwwggQUMIIC/KADAgECAgsEAAAAAAEv
# TuFS1zANBgkqhkiG9w0BAQUFADBXMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xv
# YmFsU2lnbiBudi1zYTEQMA4GA1UECxMHUm9vdCBDQTEbMBkGA1UEAxMSR2xvYmFs
# U2lnbiBSb290IENBMB4XDTExMDQxMzEwMDAwMFoXDTI4MDEyODEyMDAwMFowUjEL
# MAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExKDAmBgNVBAMT
# H0dsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gRzIwggEiMA0GCSqGSIb3DQEB
# AQUAA4IBDwAwggEKAoIBAQCU72X4tVefoFMNNAbrCR+3Rxhqy/Bb5P8npTTR94ka
# v56xzRJBbmbUgaCFi2RaRi+ZoI13seK8XN0i12pn0LvoynTei08NsFLlkFvrRw7x
# 55+cC5BlPheWMEVybTmhFzbKuaCMG08IGfaBMa1hFqRi5rRAnsP8+5X2+7UulYGY
# 4O/F69gCWXh396rjUmtQkSnF/PfNk2XSYGEi8gb7Mt0WUfoO/Yow8BcJp7vzBK6r
# kOds33qp9O/EYidfb5ltOHSqEYva38cUTOmFsuzCfUomj+dWuqbgz5JTgHT0A+xo
# smC8hCAAgxuh7rR0BcEpjmLQR7H68FPMGPkuO/lwfrQlAgMBAAGjgeUwgeIwDgYD
# VR0PAQH/BAQDAgEGMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFEbYPv/c
# 477/g+b0hZuw3WrWFKnBMEcGA1UdIARAMD4wPAYEVR0gADA0MDIGCCsGAQUFBwIB
# FiZodHRwczovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0b3J5LzAzBgNVHR8E
# LDAqMCigJqAkhiJodHRwOi8vY3JsLmdsb2JhbHNpZ24ubmV0L3Jvb3QuY3JsMB8G
# A1UdIwQYMBaAFGB7ZhpFDZfKiVAvfQTNNKj//P1LMA0GCSqGSIb3DQEBBQUAA4IB
# AQBOXlaQHka02Ukx87sXOSgbwhbd/UHcCQUEm2+yoprWmS5AmQBVteo/pSB204Y0
# 1BfMVTrHgu7vqLq82AafFVDfzRZ7UjoC1xka/a/weFzgS8UY3zokHtqsuKlYBAIH
# MNuwEl7+Mb7wBEj08HD4Ol5Wg889+w289MXtl5251NulJ4TjOJuLpzWGRCCkO22k
# aguhg/0o69rvKPbMiF37CjsAq+Ah6+IvNWwPjjRFl+ui95kzNX7Lmoq7RU3nP5/C
# 2Yr6ZbJux35l/+iS4SwxovewJzZIjyZvO+5Ndh95w+V/ljW8LQ7MAbCOf/9RgICn
# ktSzREZkjIdPFmMHMUtjsN/zMIIEnzCCA4egAwIBAgISESHWmadklz7x+EJ+6RnM
# U0EUMA0GCSqGSIb3DQEBBQUAMFIxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9i
# YWxTaWduIG52LXNhMSgwJgYDVQQDEx9HbG9iYWxTaWduIFRpbWVzdGFtcGluZyBD
# QSAtIEcyMB4XDTE2MDUyNDAwMDAwMFoXDTI3MDYyNDAwMDAwMFowYDELMAkGA1UE
# BhMCU0cxHzAdBgNVBAoTFkdNTyBHbG9iYWxTaWduIFB0ZSBMdGQxMDAuBgNVBAMT
# J0dsb2JhbFNpZ24gVFNBIGZvciBNUyBBdXRoZW50aWNvZGUgLSBHMjCCASIwDQYJ
# KoZIhvcNAQEBBQADggEPADCCAQoCggEBALAXrqLTtgQwVh5YD7HtVaTWVMvY9nM6
# 7F1eqyX9NqX6hMNhQMVGtVlSO0KiLl8TYhCpW+Zz1pIlsX0j4wazhzoOQ/DXAIlT
# ohExUihuXUByPPIJd6dJkpfUbJCgdqf9uNyznfIHYCxPWJgAa9MVVOD63f+ALF8Y
# ppj/1KvsoUVZsi5vYl3g2Rmsi1ecqCYr2RelENJHCBpwLDOLf2iAKrWhXWvdjQIC
# KQOqfDe7uylOPVOTs6b6j9JYkxVMuS2rgKOjJfuv9whksHpED1wQ119hN6pOa9PS
# UyWdgnP6LPlysKkZOSpQ+qnQPDrK6Fvv9V9R9PkK2Zc13mqF5iMEQq8CAwEAAaOC
# AV8wggFbMA4GA1UdDwEB/wQEAwIHgDBMBgNVHSAERTBDMEEGCSsGAQQBoDIBHjA0
# MDIGCCsGAQUFBwIBFiZodHRwczovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0
# b3J5LzAJBgNVHRMEAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMEIGA1UdHwQ7
# MDkwN6A1oDOGMWh0dHA6Ly9jcmwuZ2xvYmFsc2lnbi5jb20vZ3MvZ3N0aW1lc3Rh
# bXBpbmdnMi5jcmwwVAYIKwYBBQUHAQEESDBGMEQGCCsGAQUFBzAChjhodHRwOi8v
# c2VjdXJlLmdsb2JhbHNpZ24uY29tL2NhY2VydC9nc3RpbWVzdGFtcGluZ2cyLmNy
# dDAdBgNVHQ4EFgQU1KKESjhaGH+6TzBQvZ3VeofWCfcwHwYDVR0jBBgwFoAURtg+
# /9zjvv+D5vSFm7DdatYUqcEwDQYJKoZIhvcNAQEFBQADggEBAI+pGpFtBKY3IA6D
# lt4j02tuH27dZD1oISK1+Ec2aY7hpUXHJKIitykJzFRarsa8zWOOsz1QSOW0zK7N
# ko2eKIsTShGqvaPv07I2/LShcr9tl2N5jES8cC9+87zdglOrGvbr+hyXvLY3nKQc
# MLyrvC1HNt+SIAPoccZY9nUFmjTwC1lagkQ0qoDkL4T2R12WybbKyp23prrkUNPU
# N7i6IA7Q05IqW8RZu6Ft2zzORJ3BOCqt4429zQl3GhC+ZwoCNmSIubMbJu7nnmDE
# Rqi8YTNsz065nLlq8J83/rU9T5rTTf/eII5Ol6b9nwm8TcoYdsmwTYVQ8oDSHQb1
# WAQHsRgwggWuMIIElqADAgECAhAHA3HRD3laQHGZK5QHYpviMA0GCSqGSIb3DQEB
# CwUAMHwxCzAJBgNVBAYTAlVTMQswCQYDVQQIEwJNSTESMBAGA1UEBxMJQW5uIEFy
# Ym9yMRIwEAYDVQQKEwlJbnRlcm5ldDIxETAPBgNVBAsTCEluQ29tbW9uMSUwIwYD
# VQQDExxJbkNvbW1vbiBSU0EgQ29kZSBTaWduaW5nIENBMB4XDTE4MDYyMTAwMDAw
# MFoXDTIxMDYyMDIzNTk1OVowgbkxCzAJBgNVBAYTAlVTMQ4wDAYDVQQRDAU4MDIw
# NDELMAkGA1UECAwCQ08xDzANBgNVBAcMBkRlbnZlcjEYMBYGA1UECQwPMTIwMSA1
# dGggU3RyZWV0MTAwLgYDVQQKDCdNZXRyb3BvbGl0YW4gU3RhdGUgVW5pdmVyc2l0
# eSBvZiBEZW52ZXIxMDAuBgNVBAMMJ01ldHJvcG9saXRhbiBTdGF0ZSBVbml2ZXJz
# aXR5IG9mIERlbnZlcjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMtX
# iSjEDjYNBIYXsPnFGHwZqvS5lgRNSaQjsyxgLsGI6yLLDCpaYy3CBwN1on4QnYzE
# QpsHV+TJ/3K61ZvqAxhR6Anw8TjVjaB3kPdtKJjEUlgiXNK0nDRyMVasZyeXALR5
# STSf1SxoMt8HIDd0KTB8yhME6ezFdFzwB5He2/jyOswfYsN+n4k2Q9UcaVtWgCzW
# ua39anwNva7M4GugPO5ZkF6XkrGzRHpXctV/Fk6LmqPY6sRm45nScnC1KQ3NN/t6
# ZBHzmAtgbZa41o5+AvNdkv9TVF6S3ODGpf3qKW8kjFt82LLYdZi0V07ln+S/BtAl
# GUPOvqem4EkbMtZ5M3MCAwEAAaOCAewwggHoMB8GA1UdIwQYMBaAFK41Ixf//wY9
# nFDgjCRlMx5wEIiiMB0GA1UdDgQWBBSl6YhuvPlIpfXzOIq+Y/mkDGObDzAOBgNV
# HQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDAzAR
# BglghkgBhvhCAQEEBAMCBBAwZgYDVR0gBF8wXTBbBgwrBgEEAa4jAQQDAgEwSzBJ
# BggrBgEFBQcCARY9aHR0cHM6Ly93d3cuaW5jb21tb24ub3JnL2NlcnQvcmVwb3Np
# dG9yeS9jcHNfY29kZV9zaWduaW5nLnBkZjBJBgNVHR8EQjBAMD6gPKA6hjhodHRw
# Oi8vY3JsLmluY29tbW9uLXJzYS5vcmcvSW5Db21tb25SU0FDb2RlU2lnbmluZ0NB
# LmNybDB+BggrBgEFBQcBAQRyMHAwRAYIKwYBBQUHMAKGOGh0dHA6Ly9jcnQuaW5j
# b21tb24tcnNhLm9yZy9JbkNvbW1vblJTQUNvZGVTaWduaW5nQ0EuY3J0MCgGCCsG
# AQUFBzABhhxodHRwOi8vb2NzcC5pbmNvbW1vbi1yc2Eub3JnMC0GA1UdEQQmMCSB
# Iml0c3N5c3RlbWVuZ2luZWVyaW5nQG1zdWRlbnZlci5lZHUwDQYJKoZIhvcNAQEL
# BQADggEBAIc2PVq7BamWAujyCQPHsGCDbM3i1OY5nruA/fOtbJ6mJvT9UJY4+61g
# rcHLzV7op1y0nRhV459TrKfHKO42uRyZpdnHaOoC080cfg/0EwFJRy3bYB0vkVP8
# TeUkvUhbtcPVofI1P/wh9ZT2iYVCerOOAqivxWqh8Dt+8oSbjSGhPFWyu04b8Ucz
# bK/97uXdgK0zNcXDJUjMKr6CbevfLQLfQiFPizaej+2fvR/jZHAvxO9W2rhd6Nw6
# gFs2q3P4CFK0+yAkFCLk+9wsp+RsRvRkvdWJp+anNvAKOyVfCj6sz5dQPAIYIyLh
# y9ze3taVKm99DQQZV/wN/ATPDftLGm0wggXrMIID06ADAgECAhBl4eLj1d5QRYXz
# JiSABeLUMA0GCSqGSIb3DQEBDQUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# TmV3IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBV
# U0VSVFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZp
# Y2F0aW9uIEF1dGhvcml0eTAeFw0xNDA5MTkwMDAwMDBaFw0yNDA5MTgyMzU5NTla
# MHwxCzAJBgNVBAYTAlVTMQswCQYDVQQIEwJNSTESMBAGA1UEBxMJQW5uIEFyYm9y
# MRIwEAYDVQQKEwlJbnRlcm5ldDIxETAPBgNVBAsTCEluQ29tbW9uMSUwIwYDVQQD
# ExxJbkNvbW1vbiBSU0EgQ29kZSBTaWduaW5nIENBMIIBIjANBgkqhkiG9w0BAQEF
# AAOCAQ8AMIIBCgKCAQEAwKAvix56u2p1rPg+3KO6OSLK86N25L99MCfmutOYMlYj
# XAaGlw2A6O2igTXrC/Zefqk+aHP9ndRnec6q6mi3GdscdjpZh11emcehsriphHMM
# zKuHRhxqx+85Jb6n3dosNXA2HSIuIDvd4xwOPzSf5X3+VYBbBnyCV4RV8zj78gw2
# qblessWBRyN9EoGgwAEoPgP5OJejrQLyAmj91QGr9dVRTVDTFyJG5XMY4DrkN3dR
# yJ59UopPgNwmucBMyvxR+hAJEXpXKnPE4CEqbMJUvRw+g/hbqSzx+tt4z9mJmm2j
# /w2nP35MViPWCb7hpR2LB8W/499Yqu+kr4LLBfgKCQIDAQABo4IBWjCCAVYwHwYD
# VR0jBBgwFoAUU3m/WqorSs9UgOHYm8Cd8rIDZsswHQYDVR0OBBYEFK41Ixf//wY9
# nFDgjCRlMx5wEIiiMA4GA1UdDwEB/wQEAwIBhjASBgNVHRMBAf8ECDAGAQH/AgEA
# MBMGA1UdJQQMMAoGCCsGAQUFBwMDMBEGA1UdIAQKMAgwBgYEVR0gADBQBgNVHR8E
# STBHMEWgQ6BBhj9odHRwOi8vY3JsLnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNB
# Q2VydGlmaWNhdGlvbkF1dGhvcml0eS5jcmwwdgYIKwYBBQUHAQEEajBoMD8GCCsG
# AQUFBzAChjNodHRwOi8vY3J0LnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNBQWRk
# VHJ1c3RDQS5jcnQwJQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5j
# b20wDQYJKoZIhvcNAQENBQADggIBAEYstn9qTiVmvZxqpqrQnr0Prk41/PA4J8HH
# nQTJgjTbhuET98GWjTBEE9I17Xn3V1yTphJXbat5l8EmZN/JXMvDNqJtkyOh26ow
# AmvquMCF1pKiQWyuDDllxR9MECp6xF4wnH1Mcs4WeLOrQPy+C5kWE5gg/7K6c9G1
# VNwLkl/po9ORPljxKKeFhPg9+Ti3JzHIxW7LdyljffccWiuNFR51/BJHAZIqUDw3
# LsrdYWzgg4x06tgMvOEf0nITelpFTxqVvMtJhnOfZbpdXZQ5o1TspxfTEVOQAsp0
# 5HUNCXyhznlVLr0JaNkM7edgk59zmdTbSGdMq8Ztuu6VyrivOlMSPWmay5MjvwTz
# uNorbwBv0DL+7cyZBp7NYZou+DoGd1lFZN0jU5IsQKgm3+00pnnJ67crdFwfz/8b
# q3MhTiKOWEb04FT3OZVp+jzvaChHWLQ8gbCORgClaZq1H3aqI7JeRkWEEEp6Tv4W
# AVsr/i7LoXU72gOb8CAzPFqwI4Excdrxp0I4OXbECHlDqU4sTInqwlMwofmxeO4u
# 94196qIqJQl+8Sykl06VktqMux84Iw3ZQLH08J8LaJ+WDUycc4OjY61I7FGxCDkb
# SQf3npXeRFm0IBn8GiW+TRDk6J2XJFLWEtVZmhboFlBLoUlqHUCKu0QOhU/+AEOq
# nY98j2zRMYIE6TCCBOUCAQEwgZAwfDELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAk1J
# MRIwEAYDVQQHEwlBbm4gQXJib3IxEjAQBgNVBAoTCUludGVybmV0MjERMA8GA1UE
# CxMISW5Db21tb24xJTAjBgNVBAMTHEluQ29tbW9uIFJTQSBDb2RlIFNpZ25pbmcg
# Q0ECEAcDcdEPeVpAcZkrlAdim+IwDQYJYIZIAWUDBAIBBQCggYQwGAYKKwYBBAGC
# NwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgCdcu05ue
# QuLZ1HUG0YUNdEvt0HEEBQetpy3Q9p+rnUwwDQYJKoZIhvcNAQEBBQAEggEAwXoL
# hZVEQgzrgQfPv+jyA4X5/KCWfBgfj8PCP5RYkRorFqqSFcjBcCcTnzWM0UaxHT2p
# P5I1123ACg3pR8GIME4v/6eJU4cT+NNSgXlo9bI558+ZZACC2ohsfcRvx/jqL2DT
# ocMBR6jNDHALHTI8dEt1v5Kg2xwl+DLz5uLNXFXDMzta9zCeGh2SEfWBRlxGOay6
# t+VTmFN5A8CzjRlkUms23Ktdn3wgBPd8AAFd87Lal7cgvtsFi/bjUzo3h/7ap4a8
# lOtk4q5CPKpQetWnul5Vh59f6YViukMv9L8R5bZYlk7A+DCnDrRIzil2OIV9Owle
# AGqzS7n+zKL7sG6pPqGCAqIwggKeBgkqhkiG9w0BCQYxggKPMIICiwIBATBoMFIx
# CzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMSgwJgYDVQQD
# Ex9HbG9iYWxTaWduIFRpbWVzdGFtcGluZyBDQSAtIEcyAhIRIdaZp2SXPvH4Qn7p
# GcxTQRQwCQYFKw4DAhoFAKCB/TAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwG
# CSqGSIb3DQEJBTEPFw0xOTA2MTkxMzM1NDJaMCMGCSqGSIb3DQEJBDEWBBRwrioE
# u40djWl9srttBSLIjco2NDCBnQYLKoZIhvcNAQkQAgwxgY0wgYowgYcwgYQEFGO4
# L6th9YOQlpUFCwAknFApM+x5MGwwVqRUMFIxCzAJBgNVBAYTAkJFMRkwFwYDVQQK
# ExBHbG9iYWxTaWduIG52LXNhMSgwJgYDVQQDEx9HbG9iYWxTaWduIFRpbWVzdGFt
# cGluZyBDQSAtIEcyAhIRIdaZp2SXPvH4Qn7pGcxTQRQwDQYJKoZIhvcNAQEBBQAE
# ggEAZMw9o6rf5/qbiOBkI8Aoc7kn3tZjzjhUhP4sGyGVZ/y6AKuot043FkDUZOSa
# B73Epsc4NL04rTroa2E9F0kXeFxWOkrabGjaWjGnZ7hBF38llCHyHbJGjEBIe/tl
# Vq7gFKtF1oje/BE2lTQonY9SnY5F2zqkwzgWukU7E3cJAGUPp7wprMSm9JWyxw7E
# KUZX7yGLSnMRkTsz29wZ73O+Pq99m8YzfZo7zdcnF1Q5vilCxC6/tMz9yh8F/qd/
# Ehkdh9JKMK1c7SA8V+AG+fcjdiTLCq0F2my8BT8aHRYTlCJd4KKbyeNkTz+l5GkE
# uGIYDIOuWLyb8cS+TvwtLUCfVQ==
# SIG # End signature block
