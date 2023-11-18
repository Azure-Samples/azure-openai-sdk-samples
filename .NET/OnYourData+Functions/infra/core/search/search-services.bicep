metadata description = 'Creates an Azure Cognitive Search instance.'
param name string
param location string = resourceGroup().location
param tags object = {}
param storageAccountName string

param sku object = {
  name: 'standard'
}

param authOptions object = {
  aadOrApiKey: {
    aadAuthFailureMode: 'http401WithBearerChallenge'
  }
}
param disableLocalAuth bool = false
param disabledDataExfiltrationOptions array = []
param encryptionWithCmk object = {
  enforcement: 'Unspecified'
}
@allowed([
  'default'
  'highDensity'
])
param hostingMode string = 'default'
param networkRuleSet object = {
  bypass: 'None'
  ipRules: []
}
param partitionCount int = 1
@allowed([
  'enabled'
  'disabled'
])
param publicNetworkAccess string = 'enabled'
param replicaCount int = 1
@allowed([
  'disabled'
  'free'
  'standard'
])
param semanticSearch string = 'free'

resource search 'Microsoft.Search/searchServices@2021-04-01-preview' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    authOptions: authOptions
    disableLocalAuth: disableLocalAuth
    disabledDataExfiltrationOptions: disabledDataExfiltrationOptions
    encryptionWithCmk: encryptionWithCmk
    hostingMode: hostingMode
    networkRuleSet: networkRuleSet
    partitionCount: partitionCount
    publicNetworkAccess: publicNetworkAccess
    replicaCount: replicaCount
    semanticSearch: semanticSearch
  }
  sku: sku
}

// module storage '../storage/storage-account.bicep' = {
//   name: 'storage'
//   params: {
//     name: storageAccountName
//     location: location
//     tags: tags
//     containers: [
//       {
//         name: 'fileupload-container'
//       }
//     ]
//   }
// }

// resource storageAcct 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
//   name: storageAccountName
// }
// resource deploymentIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
//   name: '${storageAcct.name}-deployment-identity'
//   location: location
// }

// @description('This is the built-in Storage Blob Data Reader role. See https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-reader')
// resource storageBlobDataReaderRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
//   scope: subscription()
//   name: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
// }

// resource storageBlobDataReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   scope: storageAcct
//   name: guid(storageAcct.id, deploymentIdentity.id, storageBlobDataReaderRoleDefinition.id)
//   properties: {
//     roleDefinitionId: storageBlobDataReaderRoleDefinition.id
//     principalId: deploymentIdentity.properties.principalId
//     principalType: 'ServicePrincipal'
//   }
// }

var dataSourceConnectionString = '"ResourceId=${az.subscription().id}/resourceGroups/${az.resourceGroup().name}/providers/Microsoft.Storage/storageAccounts/${storageAccountName}/;"'

module setupSearchService 'setup-search-service.bicep' = {
  name: 'setup-search-service'
  params: {
    dataSourceContainerName: 'file-container'
    dataSourceConnectionString: dataSourceConnectionString
    dataSourceType: 'azureblob'
    location: location
    searchServiceName: search.name
  }
}

output id string = search.id
output endpoint string = 'https://${name}.search.windows.net/'
output name string = search.name
