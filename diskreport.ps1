<#******************************************************************************************
Title: Disk Report
Author: Mark B. Johnson
Date: 04/26/2018
Build: 2.0
Version: 1.5

.Description: This script will pull all computers from an OU and any sub-OUs listed
in the $OU variable. It saves this as a text file. It's currently set to look for
machines with an OS that includes Windows Server. It then checks each server in
the list and grabs the disk storage statistics and dumps it into a CSV. It also will
create an error log file to troubleshoot servers it cannot connect to.

NOTE:There are some variables you need to check before running.
$path - location for server list text file.
$OU - The Parent OU to start searching for servers. It will look through all sub-OUs also.
$outfile - Location for disk report CSV.
$ErrorPath - Location for error log report.

Revision History:
Version 1.0 - Initial set up of script and troubleshooting (4/26/2018 by mbjohnson)
Version 1.5 - Added error checking for RPC error and added creation of error log of servers
that didn't respond. (5/24/2018 by mbjohnson)
************************************************************************************************#>


#Variables
$path = "<Insert Path Here>\servers.txt"
$OU = "<Insert OU Path Here>"
$date = (Get-Date).tostring("yyyyMMdd")
$outfile = "<Insert Path Here>\diskreport_$date.csv"
$ErrorPath = "<Insert Path Here>\diskreporterrorlog_$date.txt"

#Get server list
Get-ADComputer -searchBase $OU -searchScope subtree -Properties OperatingSystem -filter {OperatingSystem -like "*windows*server*"} | Select Name | Sort Name | Out-File $path
#formatting data
$content = Get-Content $path
$content | Select-Object -Skip 3 |Foreach {$_.TrimEnd()} | Where { $_ } | Set-Content $path

#Get drive status
$file = Get-Content $path
$host.PrivateData.WarningBackgroundColor = 'DarkGreen' #Set Warning message background color for next step
$host.PrivateData.WarningForegroundColor = 'White' #Set Warning message foreground color for next step

$DskRpt = ForEach ($comp in $file)
 {
  Write-Verbose "Connecting to computer: $comp" -Verbose
  Try {
      Get-WmiObject win32_logicaldisk -ComputerName $comp -Filter "Drivetype=3" -ErrorAction Stop
  }
  Catch {
    $ErrorMessage = $_.Exception.Message
    $ErrorTimestamp = Get-Date -Format G
    Write-Warning "$comp is not reachable. RPC server unavailable is the likely issue. Check Error log file for details."
    Add-Content -Path $ErrorPath "${ErrorTimestamp}: $comp - $ErrorMessage"
    Continue
  }
 }

 #Set console colors back to default
 $host.PrivateData.WarningBackgroundColor = 'Black'
 $host.PrivateData.WarningForegroundColor = 'Yellow'

#Create Report
$DskRpt |
Select-Object @{Label = "Server Name";Expression = {$_.SystemName}},
@{Label = "Drive Letter";Expression = {$_.DeviceID}},
@{Label = "Total Capacity (GB)";Expression = {"{0:N1}" -f( $_.Size / 1gb)}},
@{Label = "Free Space (GB)";Expression = {"{0:N1}" -f( $_.Freespace / 1gb ) }},
@{Label = 'Free Space (%)'; Expression = {"{0:P0}" -f ($_.freespace/$_.size)}},
@{Label = "Volume Name";Expression = {$_.VolumeName}} | Export-CSV -Path $outfile -NoTypeInformation