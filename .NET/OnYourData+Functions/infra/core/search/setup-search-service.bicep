param searchServiceName string

param location string

param dataSourceType string

param dataSourceConnectionString string = ''

param dataSourceContainerName string

resource searchService 'Microsoft.Search/searchServices@2022-09-01' existing = {
  name: searchServiceName
}

resource deploymentIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${searchService.name}-deployment-identity'
  location: location
}

@description('Grants full access to Azure Cognitive Search index data. See https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#search-index-data-contributor')
resource searchIndexDataContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
}

// @description('This is the built-in Storage Blob Data Reader role. See https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-file-data-smb-share-contributor')
// resource storageFileDataSMBShareContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
//   // scope: subscription()
//   name: '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb'
// }

resource indexContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(searchService.id, deploymentIdentity.id, searchIndexDataContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: searchIndexDataContributorRoleDefinition.id
    principalId: deploymentIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource setupSearchService 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${searchServiceName}-setup'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentIdentity.id}': {}
    }
  }
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '8.3'
    timeout: 'PT6M'
    arguments: '-dataSourceContainerName \\"${dataSourceContainerName}\\" -dataSourceConnectionString \\"${dataSourceConnectionString}\\" -dataSourceType \\"${dataSourceType}\\" -searchServiceName \\"${searchServiceName}\\"'
    scriptContent: loadTextContent('SetupSearchService.ps1')
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
}

output indexName string = setupSearchService.properties.outputs.indexName
