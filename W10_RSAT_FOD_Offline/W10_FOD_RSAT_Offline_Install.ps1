# Supports RSAT Windows 10 1809+ such as Windows 10 1903 for Feature On Demand use for
# OFFLINE installation where no internet connection is allowed or used during the OSD deployment.
# Must download the Feature On Demand media and run the Copy Source PowerShell script to only copy RSAT files

# Win10 1903 RSAT source files size = 154MB

#Specify ISO Source location
#Sources files are in current folder by using ".\". Best approach for SCCM/MDT OSD. Create SCCM package and place this PowerShell script in the same folder as RSAT content.
# Reference this script name in the SCCM/MDT command line of the task sequence step.

$FoD_Source = ".\"

#Grab the available RSAT Features

$RSAT_FoD = Get-WindowsCapability –Online | Where-Object Name -like 'RSAT*'

#Install RSAT Tools

Foreach ($RSAT_FoD_Item in $RSAT_FoD)

{

Add-WindowsCapability -Online -Name $RSAT_FoD_Item.name -Source $FoD_Source -LimitAccess

}