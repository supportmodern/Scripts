<#
.SYNOPSIS
Applies a Windows security configuration baseline to local group policy.

.DESCRIPTION
Applies a Windows security configuration baseline to local group policy.

Execute this script with one of these required command-line switches to install
the corresponding baseline:
 -Win10DomainJoined      - Windows 10 v1809, domain-joined
 -Win10NonDomainJoined   - Windows 10 v1809, non-domain-joined
 -WS2019Member           - Windows Server 2019, domain-joined member server
 -WS2019NonDomainJoined  - Windows Server 2019, non-domain-joined
 -WS2019DomainController - Windows Server 2019, domain controller

REQUIREMENTS:

* PowerShell execution policy must be configured to allow script execution; for example,
  with a command such as the following:
  Set-ExecutionPolicy RemoteSigned

* LGPO.exe must be in the Tools subdirectory or somewhere in the Path. LGPO.exe is part of
  the Security Compliance Toolkit and can be downloaded from this URL:
  https://www.microsoft.com/download/details.aspx?id=55319

.PARAMETER Win10DomainJoined
Installs security configuration baseline for Windows 10 v1809, domain-joined

.PARAMETER Win10NonDomainJoined
Installs security configuration baseline for Windows 10 v1809, non-domain-joined

.PARAMETER WS2019Member
Installs security configuration baseline for Windows Server 2019, domain-joined member server

.PARAMETER WS2019NonDomainJoined
Installs security configuration baseline for Windows Server 2019, non-domain-joined

.PARAMETER WS2019DomainController
Installs security configuration baseline for Windows Server 2019, domain controller

#>

param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Win10DJ')]
    [switch]
    $Win10DomainJoined,

    [Parameter(Mandatory = $true, ParameterSetName = 'Win10NonDJ')]
    [switch]
    $Win10NonDomainJoined,

    [Parameter(Mandatory = $true, ParameterSetName = 'WS2019DJ')]
    [switch]
    $WS2019Member,

    [Parameter(Mandatory = $true, ParameterSetName = 'WS2019NonDJ')]
    [switch]
    $WS2019NonDomainJoined,

    [Parameter(Mandatory = $true, ParameterSetName = 'WS2019DC')]
    [switch]
    $WS2019DomainController
)

# ### EDIT THIS SECTION WHEN GPOs ARE UPDATED ###
# GPO names and GUIDs in the current baseline set
$GPO_IE11_Computer   = "MSFT Internet Explorer 11 - Computer",                                       "{ABFB52F2-1560-4100-9103-8C10F57DC9DE}"
$GPO_IE11_User       = "MSFT Internet Explorer 11 - User",                                           "{E913422C-4F06-4D37-A739-2CD2B701978E}"
$GPO_Win10_Computer  = "MSFT Windows 10 1809 - Computer",                                            "{1BB77C55-578B-49B6-AE60-7D4CB8AD29AF}"
$GPO_Win10_User      = "MSFT Windows 10 1809 - User",                                                "{927474CF-1D45-4982-A637-9CA95E8817A4}"
$GPO_Win10_BitLocker = "MSFT Windows 10 1809 - BitLocker",                                           "{3D4EEBCD-E6C0-4ADC-BAD4-0B1691A6396A}"
$GPO_All_DomainSec   = "MSFT Windows 10 1809 and Server 2019 - Domain Security",                     "{B9263530-926F-46F3-8382-832C31EC81B5}"
$GPO_All_DefenderAV  = "MSFT Windows 10 1809 and Server 2019 - Defender Antivirus",                  "{FEE76283-957E-4B25-9380-2F737E13E972}"
$GPO_CredentialGuard = "MSFT Windows 10 1809 and Server 2019 Member Server - Credential Guard",      "{7D41EEC9-3F30-4473-9447-E77D6EEF0E17}"
$GPO_WS2019_Member   = "MSFT Windows Server 2019 - Member Server",                                   "{C92CC433-A4EA-47B1-8B24-6FF732940E0E}"
$GPO_WS2019_DC       = "MSFT Windows Server 2019 - Domain Controller",                               "{FEFBD334-CF33-4078-8829-4B00DC1D164B}"
$GPO_WS2019_DC_VBS   = "MSFT Windows Server 2019 - Domain Controller Virtualization Based Security", "{7EA149BF-56B3-42CF-AF68-3FC789510ADD}"


function AddToCollection([System.Collections.Hashtable]$ht, [System.String[]]$NameAndGuid)
{
    $ht.Add($NameAndGuid[0], $NameAndGuid[1])
}

# Determine which GPOs to import
$GPOs = @{}
$baselineLabel = ""

# ### EDIT THIS SECTION IF WHICH GPOs TO BE APPLIED TO WHICH OSes ARE ALTERED ###
# GPOs for Windows 10
if ($Win10DomainJoined -or $Win10NonDomainJoined)
{
    if ($Win10DomainJoined)
    {
        $baselineLabel = "Windows 10 - domain-joined"
    }
    else
    {
        $baselineLabel = "Windows 10 - non-domain-joined"
    }
    AddToCollection $GPOs $GPO_IE11_Computer
    AddToCollection $GPOs $GPO_IE11_User
    AddToCollection $GPOs $GPO_Win10_Computer
    AddToCollection $GPOs $GPO_Win10_User
    AddToCollection $GPOs $GPO_Win10_BitLocker
    AddToCollection $GPOs $GPO_All_DomainSec
    AddToCollection $GPOs $GPO_All_DefenderAV
    AddToCollection $GPOs $GPO_CredentialGuard
}

# GPOs for Windows Server 2019 (not Domain Controller)
if ($WS2019Member -or $WS2019NonDomainJoined)
{
    if ($WS2019Member)
    {
        $baselineLabel = "Windows Server 2019 - domain-joined"
    }
    else
    {
        $baselineLabel = "Windows Server 2019 - non-domain-joined"
    }
    AddToCollection $GPOs $GPO_IE11_Computer
    AddToCollection $GPOs $GPO_IE11_User
    AddToCollection $GPOs $GPO_All_DomainSec
    AddToCollection $GPOs $GPO_All_DefenderAV
    AddToCollection $GPOs $GPO_CredentialGuard
    AddToCollection $GPOs $GPO_WS2019_Member
}

# GPOs for Windows Server 2019 Domain Controller
if ($WS2019DomainController)
{
    $baselineLabel = "Windows Server 2019 - domain controller"
    AddToCollection $GPOs $GPO_IE11_Computer
    AddToCollection $GPOs $GPO_IE11_User
    AddToCollection $GPOs $GPO_All_DomainSec
    AddToCollection $GPOs $GPO_All_DefenderAV
    AddToCollection $GPOs $GPO_WS2019_DC
    AddToCollection $GPOs $GPO_WS2019_DC_VBS
}

# Get location of this script
$rootDir = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)

# Verify availability of LGPO.exe; if not in path, but in Tools subdirectory, add Tools subdirectory to the path.
$origPath = ""
if ($null -eq (Get-Command LGPO.exe -ErrorAction SilentlyContinue))
{
    if (Test-Path -Path $rootDir\Tools\LGPO.exe)
    {
        $origPath = $env:Path
        $env:Path = "$rootDir\Tools;" + $origPath
        Write-Verbose $env:Path
        Write-Verbose (Get-Command LGPO.exe)
    }
    else
    {
$lgpoErr = @"

  ============================================================================================
    LGPO.exe must be in the Tools subdirectory or somewhere in the Path. LGPO.exe is part of
    the Security Compliance Toolkit and can be downloaded from this URL:
    https://www.microsoft.com/download/details.aspx?id=55319
  ============================================================================================
"@
        Write-Error $lgpoErr
        return
    }
}

################################################################################
# Preparatory...

# All log output in Unicode
$OutputEncodingPrevious = $OutputEncoding
$OutputEncoding = [System.Text.ASCIIEncoding]::Unicode

Push-Location $rootDir

# Log file full path
$logfile = [System.IO.Path]::Combine($rootDir, "BaselineInstall-" + [datetime]::Now.ToString("yyyyMMdd-HHmm-ss") + ".log")
Write-Host "Logging to $logfile ..." -ForegroundColor Cyan
$MyInvocation.MyCommand.Name + ", " + [datetime]::Now.ToString() | Out-File -LiteralPath $logfile


# Functions to simplify logging and reporting progress to the display
$dline = "=================================================================================================="
$sline = "--------------------------------------------------------------------------------------------------"
function Log([string] $line)
{
    $line | Out-File -LiteralPath $logfile -Append
}
function LogA([string[]] $lines)
{
    $lines | foreach { Log $_ }
}
function ShowProgress([string] $line)
{
    Write-Host $line -ForegroundColor Cyan
}
function ShowProgressA([string[]] $lines)
{
    $lines | foreach { ShowProgress $_ }
}
function LogAndShowProgress([string] $line)
{
    Log $line
    ShowProgress $line
}
function LogAndShowProgressA([string[]] $lines)
{
    $lines | foreach { LogAndShowProgress $_ }
}


LogAndShowProgress $sline
LogAndShowProgress $baselineLabel
LogAndShowProgress "GPOs to be installed:"
$GPOs.Keys | Sort-Object | foreach { 
    LogAndShowProgress "`t$_" 
}
LogAndShowProgress $dline
Log ""

################################################################################

# Wrapper to run LGPO.exe so that both stdout and stderr are redirected and
# PowerShell doesn't bitch about content going to stderr.
function RunLGPO([string] $lgpoParams)
{
    ShowProgress "Running LGPO.exe $lgpoParams"
    LogA (cmd.exe /c "LGPO.exe $lgpoParams 2>&1")
}

################################################################################

# Non-GPOs and preparatory...

LogAndShowProgress "Copy custom administrative templates..."
Copy-Item -Force ..\Templates\*.admx $env:windir\PolicyDefinitions
Copy-Item -Force ..\Templates\*.adml $env:windir\PolicyDefinitions\en-US
Log $dline

LogAndShowProgress "Configuring Client Side Extensions..."
RunLGPO "/v /e mitigation /e audit /e zone"
Log $dline

LogAndShowProgress "Installing Exploit Protection settings..."
# TODO: Some way to capture this output?
Set-ProcessMitigation -PolicyFilePath $rootDir\ConfigFiles\EP.xml
Log $dline

if ($Win10DomainJoined -or $Win10NonDomainJoined)
{
    LogAndShowProgress "Disable Xbox scheduled task on Win10..."
    LogA (SCHTASKS.EXE /Change /TN \Microsoft\XblGameSave\XblGameSaveTask /DISABLE)
    Log $dline
}

# Install the GPOs
$GPOs.Keys | Sort-Object | foreach {
    $gpoName = $_
    $gpoGuid = $GPOs[$gpoName]

    Log $sline
    LogAndShowProgress "Applying GPO `"$gpoName`"..." # ( $gpoGuid )..."
    Log $sline
    Log ""
    RunLGPO "/v /g  ..\GPOs\$gpoGuid"
    Log $dline
    Log ""
}

# For non-domain-joined, back out the local-account restrictions
if ($Win10NonDomainJoined -or $WS2019NonDomainJoined)
{
    LogAndShowProgress "Non-domain-joined: back out the local-account restrictions..."
    RunLGPO "/v /s ConfigFiles\DeltaForNonDomainJoined.inf /t ConfigFiles\DeltaForNonDomainJoined.txt"
}

# Restore original path if modified
if ($origPath.Length -gt 0)
{
    $env:Path = $origPath
}
# Restore original output encoding
$OutputEncoding = $OutputEncodingPrevious

# Restore original directory location
Pop-Location

################################################################################
$exitMessage = @"
To test properly, create a new non-administrative user account and reboot.

Detailed logs are in this file:
$logfile

Please post feedback to the Security Guidance blog:
https://blogs.technet.microsoft.com/secguide/
"@

Write-Host $dline
Write-Host $dline
Write-Host $exitMessage
Write-Host $dline
Write-Host $dline


################################################################################
