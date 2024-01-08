param name string
param location string = resourceGroup().location
param tags object = {}
param customSubDomainName string = name
param deployments array = [
  {
    name: 'chat'
    model: {
      format: 'OpenAI'
      name: 'gpt-35-turbo'
      version: '0613'
    }
    sku: {
      name: 'Standard'
      capacity: 1
    }
  }
  {
    name: 'search'
    model: {
      format: 'OpenAI'
      name: 'gpt-35-turbo-16k'
      version: '0613'
    }
    sku: {
      name: 'Standard'
      capacity: 1
    }
  }
]

param kind string = 'OpenAI'
param publicNetworkAccess string = 'Enabled'
param sku object = {
  name: 'S0'
}

resource openAiResource 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  sku: sku
  kind: kind
  properties: {
    customSubDomainName: customSubDomainName
    publicNetworkAccess: publicNetworkAccess
  }
}

@batchSize(1)
resource modelDeployments 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for item in deployments: {
  parent: openAiResource
  name: item.name
  sku: (contains(item, 'sku') ? item.sku : {
    name: 'Standard'
    capacity: item.capacity
  })
  properties: {
    model: item.model
    raiPolicyName: (contains(item, 'raiPolicyName') ? item.raiPolicyName : null)
  }
}]

output endpoint string = openAiResource.properties.endpoint
output id string = openAiResource.id
output aiDeployment string = modelDeployments[0].name
output searchDeployment string = modelDeployments[1].name
