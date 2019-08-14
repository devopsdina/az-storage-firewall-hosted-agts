param(
 [Parameter(Mandatory=$true)]
 [string]
 $SubscriptionId,

 [Parameter(Mandatory=$true)]
 [string]
 $ResourceGroupName,

 [Parameter(Mandatory=$false)]
 [string]
 $storageAccountName,

 [Parameter(Mandatory=$false)]
 [string]
 $containerName,

 [Parameter(Mandatory=$true)]
 [string]$ClientID = $env:ClientID,
 
 [Parameter(Mandatory=$true)]
 [string]$ClientSecret = $env:ClientSecret,
 
 [Parameter(Mandatory=$true)]
 [string]$TenantID = $env:TenantID
)
$ErrorActionPreference = "Stop"

If ($env:Agent_Name -eq 'Hosted Agent') {
  # verify AzureRM\Az modules are installed when using hosted agents
  Write-Output "Deploy is running on a hosted agent..."
  $azureRMInstalled = Get-InstalledModule -Name AzureRM -MinimumVersion '6.7.0' -ErrorAction SilentlyContinue
  $azInstalled = Get-Module Az.Compute -ErrorAction SilentlyContinue

  if ((-not $azureRMInstalled) -and (-not $azInstalled)) {
    Install-Module -Name AzureRM -RequiredVersion '6.7.0' -AllowClobber -Force
    Import-Module AzureRM -RequiredVersion '6.7.0' -Force
  } 
  elseif ($azInstalled) {
    Enable-AzureRmAlias
  }
}

$buildCredential = (New-Object System.Management.Automation.PSCredential $ClientID, (ConvertTo-SecureString $ClientSecret -AsPlainText -Force))
Login-AzureRmAccount -Credential $buildCredential -ServicePrincipal -TenantId $TenantID

Select-AzureRmSubscription -SubscriptionID $subscriptionId

Set-Location $PSScriptRoot

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$allowedIP = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content

$guid = ((New-Guid).guid).Substring(1,4)

if (-not $storageAccountName) {
  $storageAccountName = "storagefoo$($guid)"
}

if (-not $containerName) {
  $containerName = "containerfoo-$($guid)"
}

$param = @{
  storageAccountName = $storageAccountName
  containerName = $containerName
  allowedIP = $allowedIP
}

Write-Output "Starting deployment..."
New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile './azuredeploy.json' -TemplateParameterObject $param -Mode 'Incremental' -Verbose
