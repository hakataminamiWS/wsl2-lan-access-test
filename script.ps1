if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("Administrators")) {
    Start-Process `
        -FilePath pwsh.exe `
        -ArgumentList "-ExecutionPolicy RemoteSigned -File `"$PSCommandPath`"" `
        -PassThru `
        -Verb RunAs
    exit
}

$ip = bash.exe -c "ip r |tail -n1|cut -d ' ' -f9"
if ( ! $ip ) {
    Write-Output "The Script Exited, the ip address of WSL 2 cannot be found"
    exit
}

# All the ports you want to forward separated by comma
$ports = @(9000, 9443)

# Remove Firewall Exception Rules
Remove-NetFireWallRule -DisplayName 'WSL 2 Firewall Unlock'

# Adding Exception Rules for inbound and outbound Rules
$null = New-NetFireWallRule -DisplayName 'WSL 2 Firewall Unlock' -Profile Private -Direction Outbound -LocalPort $ports -Action Allow -Protocol TCP
$null = New-NetFireWallRule -DisplayName 'WSL 2 Firewall Unlock' -Profile Private -Direction Inbound -LocalPort $ports -Action Allow -Protocol TCP

# Show Firewall Exception Rules
Get-NetFirewallRule -DisplayName 'WSL 2 Firewall Unlock' | Format-Table -Property Name, `
    DisplayName, `
    DisplayGroup, `
@{Name = 'Protocol'; Expression = { ($PSItem | Get-NetFirewallPortFilter).Protocol } }, `
@{Name = 'LocalPort'; Expression = { ($PSItem | Get-NetFirewallPortFilter).LocalPort } }, `
@{Name = 'RemotePort'; Expression = { ($PSItem | Get-NetFirewallPortFilter).RemotePort } }, `
@{Name = 'RemoteAddress'; Expression = { ($PSItem | Get-NetFirewallAddressFilter).RemoteAddress } }, `
    Enabled, `
    Profile, `
    Direction, `
    Action

# Adding port fowarding
foreach ($port in $ports) {
    netsh interface portproxy add v4tov4 listenport=$port listenaddress=* connectport=$port connectaddress=$ip
}

# Show proxies
netsh interface portproxy show v4tov4