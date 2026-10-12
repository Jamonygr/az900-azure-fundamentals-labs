targetScope = 'resourceGroup'

@description('Canonical region name selected explicitly by the learner.')
param location string
@description('The lifecycle tool supplies Lab 18 ownership.')
@allowed(['18'])
param labId string
@minLength(4)
@maxLength(12)
param runId string

var ownership = {
  'az900-project': 'az900-azure-fundamentals-labs'
  'az900-lab': labId
  'az900-run': runId
}

resource network 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-az900'
  location: location
  tags: ownership
  properties: {
    addressSpace: { addressPrefixes: ['10.90.0.0/16'] }
    subnets: [
      {
        name: 'subnet-default'
        properties: { addressPrefix: '10.90.1.0/24' }
      }
    ]
  }
}

output virtualNetworkName string = network.name
