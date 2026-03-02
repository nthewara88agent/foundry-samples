/*
Spoke 2 VNet Module
--------------------
Deploys:
- Spoke2 VNet (10.2.0.0/16) with default subnet
- Linux VM (Ubuntu 24.04 LTS, Standard_B2s) — jumpbox
- NIC (no public IP)
- UDR attached to default subnet
*/

@description('Azure region for the deployment')
param location string

@description('Unique suffix for resource names')
param suffix string

@description('Spoke2 VNet name')
param spoke2VnetName string = 'spoke2-vnet'

@description('Spoke2 VNet address space')
param spoke2VnetAddressPrefix string = '10.2.0.0/16'

@description('Spoke2 default subnet prefix')
param spoke2SubnetPrefix string = '10.2.0.0/24'

@description('Route table ID to attach to the subnet')
param routeTableId string

@description('VM admin username')
param vmAdminUsername string = 'azureuser'

@secure()
@description('SSH public key for VM authentication. Must be provided at deploy time.')
param vmSshPublicKey string

// ---- Spoke2 VNet ----
resource spoke2Vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: spoke2VnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [spoke2VnetAddressPrefix]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: spoke2SubnetPrefix
          routeTable: { id: routeTableId }
        }
      }
    ]
  }
}

// ---- NIC for jumpbox (no public IP) ----
resource jumpboxNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'jumpbox-nic-${suffix}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: '${spoke2Vnet.id}/subnets/default' }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// ---- Linux Jumpbox VM ----
resource jumpboxVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'jumpbox-${suffix}'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B2s' }
    osProfile: {
      computerName: 'jumpbox'
      adminUsername: vmAdminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${vmAdminUsername}/.ssh/authorized_keys'
              keyData: vmSshPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-noble'
        sku: '24_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'Standard_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [{ id: jumpboxNic.id }]
    }
  }
}

output spoke2VnetName string = spoke2Vnet.name
output spoke2VnetId string = spoke2Vnet.id
output jumpboxPrivateIp string = jumpboxNic.properties.ipConfigurations[0].properties.privateIPAddress
