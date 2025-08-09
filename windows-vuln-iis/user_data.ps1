<powershell>
# Disable automatic updates to simulate outdated environment
Set-Service wuauserv -StartupType Disabled
Stop-Service wuauserv

# Enable IIS and basic features
Install-WindowsFeature -name Web-Server -IncludeManagementTools

# Enable directory browsing
Set-WebConfigurationProperty -filter "/system.webServer/directoryBrowse" -name enabled -value "true"

# Create a landing page
$indexPath = "C:\inetpub\wwwroot\index.html"
"Windows Vuln IIS Lab - Potentially Vulnerable Server" | Out-File -FilePath $indexPath -Encoding utf8

# Write a dummy canary key file
$canaryPath = "C:\inetpub\wwwroot\canary.txt"
"ghp_examplecanarykey1234567890" | Out-File -FilePath $canaryPath -Encoding utf8

# Optional link to DSPM leak (simulation)
$dspmLeakPath = "C:\inetpub\wwwroot\dspm_leak.csv"
"Simulated DSPM leaked data from Act II" | Out-File -FilePath $dspmLeakPath -Encoding utf8
</powershell>