metadata description = 'Creates an Azure storage account.'
param name string

@description('Name of the file as it is stored in the file share')
param filename string = 'SMEs.md'

@description('UTC timestamp used to create distinct deployment scripts for each deployment')
param utcValue string = utcNow()

// @description('Name of the file share')
// param fileShareName string = 'oyd-datashare'

@description('Azure region where resources should be deployed')
param location string = resourceGroup().location
param tags object = {}

@allowed([
  'Cool'
  'Hot'
  'Premium' ])
param accessTier string = 'Hot'
param allowBlobPublicAccess bool = false
param allowCrossTenantReplication bool = true
param allowSharedKeyAccess bool = true
param blobcontainer string = 'oyd-blobcontainer'
param defaultToOAuthAuthentication bool = false
param deleteRetentionPolicy object = {}
@allowed([ 'AzureDnsZone', 'Standard' ])
param dnsEndpointType string = 'Standard'
param kind string = 'StorageV2'
param minimumTlsVersion string = 'TLS1_2'
param supportsHttpsTrafficOnly bool = true
param networkAcls object = {
  bypass: 'AzureServices'
  defaultAction: 'Allow'
}
@allowed([ 'Enabled', 'Disabled' ])
param publicNetworkAccess string = 'Enabled'
param sku object = { name: 'Standard_LRS' }

resource blobstorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: name
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: tags

  properties: {
    azureFilesIdentityBasedAuthentication: {
      directoryServiceOptions: 'None'
      defaultSharePermission: 'StorageFileDataSmbShareContributor'
    }
  }

  resource blobServices 'blobServices' = {
    name: 'default'

    resource share 'shares' = {
      name: fileShareName
    }
    resource container 'containers' = {
      name: blobcontainer
    }
  }
}

@description('Executes a deployment script to upload our example file to the file share')
resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'deployscript-upload-file-${utcValue}'
  location: location
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.26.1'
    timeout: 'PT5M'
    retentionInterval: 'PT1H'
    environmentVariables: [
      {
        name: 'AZURE_STORAGE_ACCOUNT'
        value: blobstorage.name
      }
      {
        name: 'AZURE_STORAGE_KEY'
        secureValue: blobstorage.listKeys().keys[0].value
      }
      {
        name: 'CONTENT'
        value: loadTextContent('../../../azure-openai-bin/MyData/SMEs.md')
      }
    ]
    scriptContent: 'echo "$CONTENT" > ${filename} && az storage blob upload -f ${filename} -c ${blobcontainer} -n ${filename}'
  }
}

output name string = blobstorage.name
output container string = blobcontainer
