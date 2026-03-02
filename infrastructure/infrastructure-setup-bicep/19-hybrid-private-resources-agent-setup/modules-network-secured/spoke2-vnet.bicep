/*
Spoke 2 VNet Module
--------------------
Deploys:
- Spoke2 VNet (10.2.0.0/16) with default subnet
- Windows 11 VM (Standard_D4s_v5) — jumpbox
- NIC (no public IP)
- UDR attached to default subnet
- Auto-shutdown at 22:00 AWST (14:00 UTC)
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

@secure()
@description('Admin username for the jumpbox VM. Must be provided at deploy time.')
param vmAdminUsername string

@secure()
@description('Admin password for the jumpbox VM. Must be provided at deploy time.')
param vmAdminPassword string

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

// ---- Windows 11 Jumpbox VM ----
resource jumpboxVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'jumpbox-${suffix}'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_D4s_v5' }
    osProfile: {
      computerName: 'jumpbox1'
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'windows-11'
        sku: 'win11-24h2-pro'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: 128
        managedDisk: { storageAccountType: 'Premium_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [{ id: jumpboxNic.id }]
    }
  }
}

// ---- Auto-shutdown at 22:00 AWST (14:00 UTC) ----
resource autoShutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-jumpbox-${suffix}'
  location: location
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: '1400'
    }
    timeZoneId: 'UTC'
    targetResourceId: jumpboxVm.id
    notificationSettings: {
      status: 'Disabled'
    }
  }
}

output spoke2VnetName string = spoke2Vnet.name
output spoke2VnetId string = spoke2Vnet.id
output jumpboxPrivateIp string = jumpboxNic.properties.ipConfigurations[0].properties.privateIPAddress
