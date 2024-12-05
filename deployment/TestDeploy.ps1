# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See LICENSE file in the project root for license information.

#
# Powershell script to deploy the resources - Customer portal, Publisher portal and the Azure SQL Database
#

#.\Deploy.ps1 `
# -WebAppNamePrefix "amp_saas_accelerator_<unique>" `
# -Location "<region>" `
# -PublisherAdminUsers "<your@email.address>"

Param(  
   [string][Parameter(Mandatory)]$WebAppNamePrefix, # Prefix used for creating web applications
   [string][Parameter()]$ResourceGroupForDeployment, # Name of the resource group to deploy the resources
   [string][Parameter(Mandatory)]$Location, # Location of the resource group
   [string][Parameter(Mandatory)]$PublisherAdminUsers, # Provide a list of email addresses (as comma-separated-values) that should be granted access to the Publisher Portal
   [string][Parameter()]$TenantID, # The value should match the value provided for Active Directory TenantID in the Technical Configuration of the Transactable Offer in Partner Center
   [string][Parameter()]$AzureSubscriptionID, # Subscription where the resources be deployed
   [string][Parameter()]$ADApplicationID, # The value should match the value provided for Active Directory Application ID in the Technical Configuration of the Transactable Offer in Partner Center
   [string][Parameter()]$ADApplicationSecret, # Secret key of the AD Application
   [string][Parameter()]$ADApplicationIDAdmin, # Multi-Tenant Active Directory Application ID 
   [string][Parameter()]$ADMTApplicationIDPortal, #Multi-Tenant Active Directory Application ID for the Landing Portal
   [string][Parameter()]$IsAdminPortalMultiTenant, # If set to true, the Admin Portal will be configured as a multi-tenant application. This is by default set to false. 
   [string][Parameter()]$SQLDatabaseName, # Name of the database (Defaults to AMPSaaSDB)
   [string][Parameter()]$SQLServerName, # Name of the database server (without database.windows.net)
   [string][Parameter()]$LogoURLpng,  # URL for Publisher .png logo
   [string][Parameter()]$LogoURLico,  # URL for Publisher .ico logo
   [string][Parameter()]$KeyVault, # Name of KeyVault
   [switch][Parameter()]$Quiet #if set, only show error / warning output from script commands
)

# Define the warning message
$message = @"
The SaaS Accelerator is offered under the MIT License as open source software and is not supported by Microsoft.

If you need help with the accelerator or would like to report defects or feature requests use the Issues feature on the GitHub repository at https://aka.ms/SaaSAccelerator

Do you agree? (Y/N)
"@

# Display the message in yellow
Write-Host $message -ForegroundColor Yellow

# Prompt the user for input
$response = Read-Host

# Check the user's response
if ($response -ne 'Y' -and $response -ne 'y') {
    Write-Host "You did not agree. Exiting..." -ForegroundColor Red
    exit
}

# Proceed if the user agrees
Write-Host "Thank you for agreeing. Proceeding with the script..." -ForegroundColor Green

# Make sure to install Az Module before running this script
# Install-Module Az
# Install-Module -Name AzureAD

#region Select Tenant / Subscription for deployment

$currentContext = az account show | ConvertFrom-Json
$currentTenant = $currentContext.tenantId
$currentSubscription = $currentContext.id

#Get TenantID if not set as argument
if(!($TenantID)) {    
    Get-AzTenant | Format-Table
    if (!($TenantID = Read-Host "⌨  Type your TenantID or press Enter to accept your current one [$currentTenant]")) { $TenantID = $currentTenant }    
}
else {
    Write-Host "🔑 Tenant provided: $TenantID"
}

#Get Azure Subscription if not set as argument
if(!($AzureSubscriptionID)) {    
    Get-AzSubscription -TenantId $TenantID | Format-Table
    if (!($AzureSubscriptionID = Read-Host "⌨  Type your SubscriptionID or press Enter to accept your current one [$currentSubscription]")) { $AzureSubscriptionID = $currentSubscription }
}
else {
    Write-Host "🔑 Azure Subscription provided: $AzureSubscriptionID"
}

#Set the AZ Cli context
az account set -s $AzureSubscriptionID
Write-Host "🔑 Azure Subscription '$AzureSubscriptionID' selected."

#endregion



$ErrorActionPreference = "Stop"
$startTime = Get-Date
#region Select Tenant / Subscription for deployment

$currentContext = az account show | ConvertFrom-Json
$currentTenant = $currentContext.tenantId
$currentSubscription = $currentContext.id

#Get TenantID if not set as argument
if(!($TenantID)) {    
    Get-AzTenant | Format-Table
    if (!($TenantID = Read-Host "⌨  Type your TenantID or press Enter to accept your current one [$currentTenant]")) { $TenantID = $currentTenant }    
}
else {
    Write-Host "🔑 Tenant provided: $TenantID"
}

#Get Azure Subscription if not set as argument
if(!($AzureSubscriptionID)) {    
    Get-AzSubscription -TenantId $TenantID | Format-Table
    if (!($AzureSubscriptionID = Read-Host "⌨  Type your SubscriptionID or press Enter to accept your current one [$currentSubscription]")) { $AzureSubscriptionID = $currentSubscription }
}
else {
    Write-Host "🔑 Azure Subscription provided: $AzureSubscriptionID"
}

#Set the AZ Cli context
az account set -s $AzureSubscriptionID
Write-Host "🔑 Azure Subscription '$AzureSubscriptionID' selected."

#endregion




#region Set up Variables and Default Parameters

if ($ResourceGroupForDeployment -eq "") {
    $ResourceGroupForDeployment = $WebAppNamePrefix 
}
if ($SQLServerName -eq "") {
    $SQLServerName = $WebAppNamePrefix + "-sql"
}
if ($SQLDatabaseName -eq "") {
    $SQLDatabaseName = $WebAppNamePrefix +"AMPSaaSDB"
}

if($KeyVault -eq "")
{
# User did not define KeyVault, so we will create one. 
# We need to check if the KeyVault already exists or purge before going forward

   $KeyVault=$WebAppNamePrefix+"-kv"

   # Check if the KeyVault exists under resource group
   $kv_check=$(az keyvault show -n $KeyVault -g $ResourceGroupForDeployment) 2>$null    

   # If KeyVault does not exist under resource group, then we need to check if it deleted KeyVault
   if($kv_check -eq $null)
   {
	#region Check If KeyVault Exists
		$KeyVaultApiUri="https://management.azure.com/subscriptions/$AzureSubscriptionID/providers/Microsoft.KeyVault/checkNameAvailability?api-version=2019-09-01"
		$KeyVaultApiBody='{"name": "'+$KeyVault+'","type": "Microsoft.KeyVault/vaults"}'

		$kv_check=az rest --method post --uri $KeyVaultApiUri --headers 'Content-Type=application/json' --body $KeyVaultApiBody | ConvertFrom-Json

		if( $kv_check.reason -eq "AlreadyExists")
		{
			Write-Host ""
			Write-Host "🛑  KeyVault name "  -NoNewline -ForegroundColor Red
			Write-Host "$KeyVault"  -NoNewline -ForegroundColor Red -BackgroundColor Yellow
			Write-Host " already exists." -ForegroundColor Red
			Write-Host "   To Purge KeyVault please use the following doc:"
			Write-Host "   https://learn.microsoft.com/en-us/cli/azure/keyvault?view=azure-cli-latest#az-keyvault-purge."
			Write-Host "   You could use new KeyVault name by using parameter" -NoNewline 
			Write-Host " -KeyVault"  -ForegroundColor Green
			exit 1
		}
	#endregion
	}

}

$SaaSApiConfiguration_CodeHash= git log --format='%H' -1
$azCliOutput = if($Quiet){'none'} else {'json'}

#endregion

#region Validate Parameters

if($WebAppNamePrefix.Length -gt 21) {
    Throw "🛑 Web name prefix must be less than 21 characters."
    exit 1
}

if(!($KeyVault -match "^[a-zA-Z][a-z0-9-]+$")) {
    Throw "🛑 KeyVault name only allows alphanumeric and hyphens, but cannot start with a number or special character."
    exit 1
}


#endregion 

#region pre-checks

# check if dotnet 8 is installed

$dotnetversion = dotnet --version

if(!$dotnetversion.StartsWith('8.')) {
    Throw "🛑 Dotnet 8 not installed. Install dotnet8 and re-run the script."
    Exit
}

#endregion


Write-Host "Starting SaaS Accelerator Deployment..."


#region Check If SQL Server Exist
$sql_exists = Get-AzureRmSqlServer -ServerName $SQLServerName -ResourceGroupName $ResourceGroupForDeployment -ErrorAction SilentlyContinue
if ($sql_exists) 
{
	Write-Host ""
	Write-Host "🛑 SQl Server name " -NoNewline -ForegroundColor Red
	Write-Host "$SQLServerName"   -NoNewline -ForegroundColor Red -BackgroundColor Yellow
	Write-Host " already exists." -ForegroundColor Red
	Write-Host "Please delete existing instance or use new sql Instance name by using parameter" -NoNewline 
	Write-Host " -SQLServerName"   -ForegroundColor Green
    exit 1
}  
#endregion

#region Dowloading assets if provided

# Download Publisher's PNG logo
if($LogoURLpng) { 
    Write-Host "📷 Logo image provided"
	Write-Host "   🔵 Downloading Logo image file"
    Invoke-WebRequest -Uri $LogoURLpng -OutFile "../src/CustomerSite/wwwroot/contoso-sales.png"
    Invoke-WebRequest -Uri $LogoURLpng -OutFile "../src/AdminSite/wwwroot/contoso-sales.png"
    Write-Host "   🔵 Logo image downloaded"
}

# Download Publisher's FAVICON logo
if($LogoURLico) { 
    Write-Host "📷 Logo icon provided"
	Write-Host "   🔵 Downloading Logo icon file"
    Invoke-WebRequest -Uri $LogoURLico -OutFile "../src/CustomerSite/wwwroot/favicon.ico"
    Invoke-WebRequest -Uri $LogoURLico -OutFile "../src/AdminSite/wwwroot/favicon.ico"
    Write-Host "   🔵 Logo icon downloaded"
}

#endregion
 
#region Create AAD App Registrations

#Record the current ADApps to reduce deployment instructions at the end
$ISLoginAppProvided = ($ADApplicationIDAdmin -ne "" -or $ADMTApplicationIDPortal -ne "")


if($ISLoginAppProvided){
	Write-Host "🔑 Multi-Tenant App Registrations provided."
	Write-Host "   ➡️ Admin Portal App Registration ID:" $ADApplicationIDAdmin
	Write-Host "   ➡️ Landing Page App Registration ID:" $ADMTApplicationIDPortal
}
else {
	Write-Host "🔑 Multi-Tenant App Registrations not provided."
}



if($IsAdminPortalMultiTenant -eq "true"){
	Write-Host "🔑 Admin Portal App Registration set as Multi-Tenant."
	$IsAdminPortalMultiTenant = $true
}
else {
	Write-Host "🔑 Admin Portal App Registration set as Single-Tenant."
	$IsAdminPortalMultiTenant = $false
}






#Create App Registration for authenticating calls to the Marketplace API
if (!($ADApplicationID)) {   
    Write-Host "🔑 Creating Fulfilment API App Registration"
    try {   
        $ADApplication = az ad app create --only-show-errors --sign-in-audience AzureADMYOrg --display-name "$WebAppNamePrefix-FulfillmentAppReg" | ConvertFrom-Json
		$ADObjectID = $ADApplication.id
        $ADApplicationID = $ADApplication.appId
        sleep 5 #this is to give time to AAD to register
		# create service principal
		az ad sp create --id $ADApplicationID
        $ADApplicationSecret = az ad app credential reset --id $ADObjectID --append --display-name 'SaaSAPI' --years 2 --query password --only-show-errors --output tsv
				
        Write-Host "   🔵 FulfilmentAPI App Registration created."
		Write-Host "      ➡️ Application ID:" $ADApplicationID
    }
    catch [System.Net.WebException],[System.IO.IOException] {
        Write-Host "🚨🚨   $PSItem.Exception"
        break;
    }
}

#Create Multi-Tenant App Registration for Admin Portal User Login
if (!($ADApplicationIDAdmin)) {  
    Write-Host "🔑 Creating Admin Portal SSO App Registration"
    try {
	
		$appCreateRequestBodyJson = @"
{
	"displayName" : "$WebAppNamePrefix-AdminPortalAppReg",
	"api": 
	{
		"requestedAccessTokenVersion" : 2
	},
	"signInAudience" : "AzureADMyOrg",
	"web":
	{ 
		"redirectUris": 
		[
			
			"https://$WebAppNamePrefix-admin.azurewebsites.net",
			"https://$WebAppNamePrefix-admin.azurewebsites.net/",
			"https://$WebAppNamePrefix-admin.azurewebsites.net/Home/Index",
			"https://$WebAppNamePrefix-admin.azurewebsites.net/Home/Index/"
		],
		"logoutUrl": "https://$WebAppNamePrefix-admin.azurewebsites.net/logout",
		"implicitGrantSettings": 
			{ "enableIdTokenIssuance" : true }
	},
	"requiredResourceAccess":
	[{
		"resourceAppId": "00000003-0000-0000-c000-000000000000",
		"resourceAccess":
			[{ 
				"id": "e1fe6dd8-ba31-4d61-89e7-88639da4683d",
				"type": "Scope" 
			}]
	}]
}
"@	
		if ($PsVersionTable.Platform -ne 'Unix') {
			#On Windows, we need to escape quotes and remove new lines before sending the payload to az rest. 
			# See: https://github.com/Azure/azure-cli/blob/dev/doc/quoting-issues-with-powershell.md#double-quotes--are-lost
			$appCreateRequestBodyJson = $appCreateRequestBodyJson.replace('"','\"').replace("`r`n","")
		}

		$adminPortalAppReg = $(az rest --method POST --headers "Content-Type=application/json" --uri https://graph.microsoft.com/v1.0/applications --body $appCreateRequestBodyJson  ) | ConvertFrom-Json
	
		$ADApplicationIDAdmin = $adminPortalAppReg.appId
		$ADMTObjectIDAdmin = $adminPortalAppReg.id
	
        Write-Host "   🔵 Admin Portal SSO App Registration created."
		Write-Host "      ➡️ Application Id: $ADApplicationIDAdmin"


		# Download Publisher's AppRegistration logo
        if($LogoURLpng) { 
			Write-Host "   🔵 Logo image provided. Setting the Application branding logo"
			Write-Host "      ➡️ Setting the Application branding logo"
			$token=(az account get-access-token --resource "https://graph.microsoft.com" --query accessToken --output tsv)
			$logoWeb = Invoke-WebRequest $LogoURLpng
			$logoContentType = $logoWeb.Headers["Content-Type"]
			$logoContent = $logoWeb.Content
			
			$uploaded = Invoke-WebRequest `
			  -Uri "https://graph.microsoft.com/v1.0/applications/$ADMTObjectIDAdmin/logo" `
			  -Method "PUT" `
			  -Header @{"Authorization"="Bearer $token";"Content-Type"="$logoContentType";} `
			  -Body $logoContent
		    
			Write-Host "      ➡️ Application branding logo set."
        }

    }
    catch [System.Net.WebException],[System.IO.IOException] {
        Write-Host "🚨🚨   $PSItem.Exception"
        break;
    }
}

#Create Multi-Tenant App Registration for Landing Page User Login
if (!($ADMTApplicationIDPortal)) {  
    Write-Host "🔑 Creating Landing Page SSO App Registration"
    try {
	
		$appCreateRequestBodyJson = @"
{
	"displayName" : "$WebAppNamePrefix-LandingpageAppReg",
	"api": 
	{
		"requestedAccessTokenVersion" : 2
	},
	"signInAudience" : "AzureADandPersonalMicrosoftAccount",
	"web":
	{ 
		"redirectUris": 
		[
			"https://$WebAppNamePrefix-portal.azurewebsites.net",
			"https://$WebAppNamePrefix-portal.azurewebsites.net/",
			"https://$WebAppNamePrefix-portal.azurewebsites.net/Home/Index",
			"https://$WebAppNamePrefix-portal.azurewebsites.net/Home/Index/"
			
		],
		"logoutUrl": "https://$WebAppNamePrefix-portal.azurewebsites.net/logout",
		"implicitGrantSettings": 
			{ "enableIdTokenIssuance" : true }
	},
	"requiredResourceAccess":
	[{
		"resourceAppId": "00000003-0000-0000-c000-000000000000",
		"resourceAccess":
			[{ 
				"id": "e1fe6dd8-ba31-4d61-89e7-88639da4683d",
				"type": "Scope" 
			}]
	}]
}
"@	
		if ($PsVersionTable.Platform -ne 'Unix') {
			#On Windows, we need to escape quotes and remove new lines before sending the payload to az rest. 
			# See: https://github.com/Azure/azure-cli/blob/dev/doc/quoting-issues-with-powershell.md#double-quotes--are-lost
			$appCreateRequestBodyJson = $appCreateRequestBodyJson.replace('"','\"').replace("`r`n","")
		}

		$landingpageLoginAppReg = $(az rest --method POST --headers "Content-Type=application/json" --uri https://graph.microsoft.com/v1.0/applications --body $appCreateRequestBodyJson  ) | ConvertFrom-Json
	
		$ADMTApplicationIDPortal = $landingpageLoginAppReg.appId
		$ADMTObjectIDPortal = $landingpageLoginAppReg.id
	
        Write-Host "   🔵 Landing Page SSO App Registration created."
		Write-Host "      ➡️ Application Id: $ADMTApplicationIDPortal"
	
		# Download Publisher's AppRegistration logo
        if($LogoURLpng) { 
			Write-Host "   🔵 Logo image provided. Setting the Application branding logo"
			Write-Host "      ➡️ Setting the Application branding logo"
			$token=(az account get-access-token --resource "https://graph.microsoft.com" --query accessToken --output tsv)
			$logoWeb = Invoke-WebRequest $LogoURLpng
			$logoContentType = $logoWeb.Headers["Content-Type"]
			$logoContent = $logoWeb.Content
			
			$uploaded = Invoke-WebRequest `
			  -Uri "https://graph.microsoft.com/v1.0/applications/$ADMTObjectIDPortal/logo" `
			  -Method "PUT" `
			  -Header @{"Authorization"="Bearer $token";"Content-Type"="$logoContentType";} `
			  -Body $logoContent
		    
			Write-Host "      ➡️ Application branding logo set."
        }

    }
    catch [System.Net.WebException],[System.IO.IOException] {
        Write-Host "🚨🚨   $PSItem.Exception"
        break;
    }
}

#endregion

#region Prepare Code Packages
Write-host "📜 Prepare publish files for the application"
if (!(Test-Path '../Publish')) {		
	Write-host "   🔵 Preparing Admin Site"  
	dotnet publish ../src/AdminSite/AdminSite.csproj -c release -o ../Publish/AdminSite/ -v q

	Write-host "   🔵 Preparing Metered Scheduler"
	dotnet publish ../src/MeteredTriggerJob/MeteredTriggerJob.csproj -c release -o ../Publish/AdminSite/app_data/jobs/triggered/MeteredTriggerJob/ -v q --runtime win-x64 --self-contained true 

	Write-host "   🔵 Preparing Customer Site"
	dotnet publish ../src/CustomerSite/CustomerSite.csproj -c release -o ../Publish/CustomerSite/ -v q

	Write-host "   🔵 Zipping packages"
	Compress-Archive -Path ../Publish/AdminSite/* -DestinationPath ../Publish/AdminSite.zip -Force
	Compress-Archive -Path ../Publish/CustomerSite/* -DestinationPath ../Publish/CustomerSite.zip -Force
}
#endregion