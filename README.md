# Overview
These scripts support the deployment of WebJobs OR Function Apps to Azure App Services.

## PowerShell

### How to execute
Take the powershell script and place it in a different folder as the runtime bits of your job. Take the example call and use it to package and deploy the folder that the job's binaries / scripts.

Example execution:

```
.\Deploy-WebJob.ps1 -WebAppName '<app/site name>' -WebAppResourceGroupName '<resource group name>' -WebJobName 'test' -WebJobType '< triggered|scheduled >' -WebJobPath '<fully qualified local file path to web job folder>'
```

The script will use the `WebJobName` as the destination / deployed name of the WebJob, regardless of the `WebJobPath` folder name.

### Executing Non-Interactively

The script will need an Azure Context to execute. With interactive `Login-AzureRmAccount', it will require a user to authentication.

For non-interactive execution, such as VSTS, [see here](https://docs.microsoft.com/en-us/vsts/build-release/concepts/library/service-endpoints#sep-azure-rm).