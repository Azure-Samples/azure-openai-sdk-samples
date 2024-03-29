metadata description = 'Creates an Azure Cognitive Search instance.'
param name string
param location string = resourceGroup().location
param tags object = {}
// param containerName string = ''
// param storageAccountName string = ''

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

// module setupSearchService 'setup-search-service.bicep' = {
//   name: 'setup-search-service'
//   params: {
//     storageAccountName: storageAccountName
//     dataSourceContainerName: containerName
//     dataSourceType: 'azureblob'
//     location: location
//     searchServiceName: search.name
//   }
// }

output id string = search.id
output endpoint string = 'https://${name}.search.windows.net/'
output name string = search.name
// output index string = setupSearchService.outputs.indexName
