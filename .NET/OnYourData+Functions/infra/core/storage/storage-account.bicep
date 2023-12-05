metadata description = 'Creates an Azure storage account.'
param name string

@description('Name of the file as it is stored in the file share')
param filename string = 'SMEs.md'

@description('UTC timestamp used to create distinct deployment scripts for each deployment')
param utcValue string = utcNow()

@description('Name of the file share')
param fileShareName string = 'oyd-datashare'

@description('Azure region where resources should be deployed')
param location string = resourceGroup().location
param tags object = {}

resource storage 'Microsoft.Storage/storageAccounts@2021-04-01' = {
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

  resource fileService 'fileServices' = {
    name: 'default'

    resource share 'shares' = {
      name: fileShareName
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
        value: storage.name
      }
      {
        name: 'AZURE_STORAGE_KEY'
        secureValue: storage.listKeys().keys[0].value
      }
      {
        name: 'CONTENT'
        value: loadTextContent('../../../azure-openai-bin/MyData/SMEs.md')
      }
    ]
    scriptContent: 'echo "$CONTENT" > ${filename} && az storage file upload --source ${filename} -s ${fileShareName}'
  }
}

output name string = storage.name
