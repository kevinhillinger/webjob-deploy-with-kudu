param (
   $WebAppName,
   $WebAppResourceGroupName,
   $WebJobName,
   $WebJobType,
   $WebJobPath
)

$CURRENT_DIR = $(Resolve-Path .\).Path
$tmpPath = "$CURRENT_DIR\tmp"
$packagePath = "$CURRENT_DIR\pkg"

function createPackage($zipFileName, $folderPath) {
   Add-Type -Assembly System.IO.Compression.FileSystem

   $zipFilePath = "$packagePath\$zipFileName"
   $zipContentPath = "$tmpPath\App_Data\jobs\$WebJobType\$WebJobName"

   New-Item -ItemType Directory -Path $tmpPath -Force:$true | Out-Null 
   New-Item -ItemType Directory -Path $packagePath -Force:$true | Out-Null 
   New-Item -ItemType Directory -Path $zipContentPath -Force:$true | Out-Null

   Copy-item -Path "$WebJobPath\*" -Destination $zipContentPath -Force:$true | Out-Null

   if ((Test-Path -Path $zipFilePath) -eq $true) {
         Remove-Item $zipFilePath -Force:$true | Out-Null
   }
   
   [System.IO.Compression.ZipFile]::CreateFromDirectory($tmpPath, $zipFilePath, [System.IO.Compression.CompressionLevel]::Optimal, $false)

   return $zipFilePath
}

function cleanUp() {
   Remove-Item -Path $tmpPath -Recurse:$true -Force:$true
   Remove-Item -Path $packagePath -Recurse:$true -Force:$true
}

function getPublishProfile() {

   # must have an azure RM Context to execute this function 

   $app = Get-AzureRmWebApp -Name $WebAppName -ResourceGroupName $WebAppResourceGroupName
   $outFile = "$tmpPath\site.PublishSettings"

   Get-AzureRmWebAppPublishingProfile -ResourceGroupName $app.ResourceGroup -Name $app.Name -Format "WebDeploy" -OutputFile $outFile

   [xml]$settings = Get-Content -Path $outFile
   $profile = $settings.publishData.publishProfile | where { $_.publishMethod -eq "MSDeploy" }

   return $profile
}

function getHttpHeaders($publishProfile) {
   $publishProfile = getPublishProfile
   $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $publishProfile.userName, $publishProfile.userPWD)))

   $authHeader = "Basic {0}" -f $base64AuthInfo
   $headers = @{'Authorization'=$authHeader; }

   return $headers
}

function deployPackage($siteName, $jobType, $packageFilePath, $headers) {
   $apiUrl = "https://$siteName.scm.azurewebsites.net/api/zipdeploy"
	$result = Invoke-RestMethod -Uri $apiUrl -Headers $headers -ContentType "multipart/form-data" -Method POST -InFile $packageFilePath
}

# for more info, see https://github.com/projectkudu/kudu/wiki/Deploying-from-a-zip-file
# and Kudu API https://github.com/projectkudu/kudu/wiki/REST-API#zip-deployment-preview

function Deploy-WebJob() {
    Write-Output "Creating WebJob package"

    $zipFileName = "WebJob.zip"
    $packageFilePath = createPackage -zipFileName $zipFileName -folderPath $WebJobPath

    $publishProfile = getPublishProfile

    $headers = getHttpHeaders -publishProfile $publishProfile
    $siteName = $publishProfile.msdeploySite

    Write-Output "Deploying WebJob to $siteName..."
    deployPackage -siteName $siteName -jobType $WebJobType -packageFilePath $packageFilePath -headers $headers

    Write-Output "$WebJobName Deployment complete."

    cleanUp
}

Deploy-WebJob

#-----------------------------------------------------------------------------------


# example function on how to use the command operation to execute custom actions
function executeCommand($siteName, $headers) {
   $apiUrl = "https://$siteName.scm.azurewebsites.net/api/command"

  $command = @"
   {
     "command": "<enter command here or location to a batch file>",
     "dir": ".\\site\\wwwroot"
  }
"@	
  $result = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Body $command -ContentType "application/json" -Method POST
  $result | Out-File -FilePath '.\log.txt' -Append:$true
}
