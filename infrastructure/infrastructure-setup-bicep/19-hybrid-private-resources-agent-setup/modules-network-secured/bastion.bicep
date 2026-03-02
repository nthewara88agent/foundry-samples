/*
Azure Bastion Developer SKU Module
------------------------------------
Deploys Azure Bastion (Developer SKU) on the hub VNet.
Developer SKU does not require a public IP or dedicated subnet allocation beyond AzureBastionSubnet.
*/

@description('Azure region for the deployment')
param location string

@description('Unique suffix for resource names')
param suffix string

@description('Hub VNet ID')
param hubVnetId string

resource bastion 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: 'bastion-${suffix}'
  location: location
  sku: { name: 'Developer' }
  properties: {
    virtualNetwork: { id: hubVnetId }
  }
}

output bastionName string = bastion.name
