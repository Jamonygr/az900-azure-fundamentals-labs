// Reference template only: Setup.ps1 uses the checked CLI lifecycle by default.
// Do not deploy this template to an existing group without the same ownership and inventory checks.
targetScope = 'resourceGroup'

param location string
@allowed(['21'])
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

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'staz900${labId}${runId}'
  location: location
  tags: ownership
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

resource blobs 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {}
}

resource practice 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobs
  name: 'practice'
  properties: {
    publicAccess: 'None'
    metadata: {
      az900_project: 'az900-azure-fundamentals-labs'
      az900_lab: labId
      az900_run: runId
    }
  }
}

output virtualNetworkName string = network.name
output storageAccountName string = storage.name
