# Basic PowerShell Script Example
# File: Get-Processes.ps1

# Get all running processes
$processes = Get-Process

# Define output file path
$outputFile = "C:\Temp\RunningProcesses.txt"

# Export process list to a text file
$processes | Out-File -FilePath $outputFile

# Print confirmation
Write-Output "Process list has been saved to $outputFile"