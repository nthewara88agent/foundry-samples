/*
Hub Virtual Network Module
--------------------------
Deploys the hub VNet with:
- Azure Firewall (Standard SKU) + Firewall Policy
- Azure Firewall public IP
- Log Analytics Workspace
- Diagnostic settings on Firewall (all log categories + metrics)
- Storage account for flow logs
- VNet flow logs with traffic analytics

Subnets:
- AzureFirewallSubnet (10.0.1.0/26)
- AzureFirewallManagementSubnet (10.0.1.64/26)
- AzureBastionSubnet (10.0.2.0/26)
*/

@description('Azure region for the deployment')
param location string

@description('Unique suffix for resource names')
param suffix string

@description('Hub VNet name')
param hubVnetName string = 'hub-vnet'

@description('Hub VNet address space')
param hubVnetAddressPrefix string = '10.0.0.0/16'

@description('Azure Firewall subnet prefix')
param firewallSubnetPrefix string = '10.0.1.0/26'

@description('Azure Firewall management subnet prefix')
param firewallMgmtSubnetPrefix string = '10.0.1.64/26'

@description('Azure Bastion subnet prefix')
param bastionSubnetPrefix string = '10.0.2.0/26'

// ---- Log Analytics Workspace ----
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-hub-${suffix}'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

// ---- Storage Account for Flow Logs ----
resource flowLogStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: toLower('flowlogs${suffix}sa')
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Enabled'
  }
}

// ---- Hub Virtual Network ----
resource hubVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: hubVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [hubVnetAddressPrefix]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: firewallSubnetPrefix
        }
      }
      {
        name: 'AzureFirewallManagementSubnet'
        properties: {
          addressPrefix: firewallMgmtSubnetPrefix
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
    ]
  }
}

// ---- Firewall Public IPs ----
resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'fw-pip-${suffix}'
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource firewallMgmtPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'fw-mgmt-pip-${suffix}'
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// ---- Firewall Policy ----
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2024-05-01' = {
  name: 'fw-policy-${suffix}'
  location: location
  properties: {
    sku: { tier: 'Standard' }
    threatIntelMode: 'Alert'
  }
}

resource networkRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: firewallPolicy
  name: 'DefaultNetworkRuleCollectionGroup'
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'AllowRFC1918'
        priority: 100
        action: { type: 'Allow' }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'Allow-RFC1918-to-RFC1918'
            ipProtocols: ['Any']
            sourceAddresses: ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16']
            destinationAddresses: ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16']
            destinationPorts: ['*']
          }
        ]
      }
    ]
  }
}

resource appRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: firewallPolicy
  name: 'DefaultApplicationRuleCollectionGroup'
  properties: {
    priority: 300
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'AllowOutboundWeb'
        priority: 100
        action: { type: 'Allow' }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'Allow-HTTP-HTTPS'
            sourceAddresses: ['10.1.0.0/16', '10.2.0.0/16']
            protocols: [
              { protocolType: 'Http', port: 80 }
              { protocolType: 'Https', port: 443 }
            ]
            targetFqdns: ['*']
          }
        ]
      }
    ]
  }
  dependsOn: [networkRuleCollectionGroup]
}

// ---- Azure Firewall ----
resource firewall 'Microsoft.Network/azureFirewalls@2024-05-01' = {
  name: 'fw-hub-${suffix}'
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    firewallPolicy: { id: firewallPolicy.id }
    ipConfigurations: [
      {
        name: 'fw-ipconfig'
        properties: {
          subnet: { id: '${hubVnet.id}/subnets/AzureFirewallSubnet' }
          publicIPAddress: { id: firewallPublicIp.id }
        }
      }
    ]
    managementIpConfiguration: {
      name: 'fw-mgmt-ipconfig'
      properties: {
        subnet: { id: '${hubVnet.id}/subnets/AzureFirewallManagementSubnet' }
        publicIPAddress: { id: firewallMgmtPublicIp.id }
      }
    }
  }
  dependsOn: [appRuleCollectionGroup]
}

// ---- Firewall Diagnostic Settings ----
resource firewallDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'fw-diag-${suffix}'
  scope: firewall
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      { categoryGroup: 'allLogs', enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}

// ---- VNet Flow Logs — Hub ----
resource networkWatcher 'Microsoft.Network/networkWatchers@2024-05-01' = {
  name: 'NetworkWatcher_${location}'
  location: location
}

resource hubFlowLog 'Microsoft.Network/networkWatchers/flowLogs@2024-05-01' = {
  parent: networkWatcher
  name: 'fl-hub-${suffix}'
  location: location
  properties: {
    targetResourceId: hubVnet.id
    storageId: flowLogStorage.id
    enabled: true
    retentionPolicy: {
      days: 30
      enabled: true
    }
    format: {
      type: 'JSON'
      version: 2
    }
    flowAnalyticsConfiguration: {
      networkWatcherFlowAnalyticsConfiguration: {
        enabled: true
        workspaceResourceId: logAnalytics.id
        workspaceRegion: location
        workspaceId: logAnalytics.properties.customerId
        trafficAnalyticsInterval: 10
      }
    }
  }
}

// ---- Outputs ----
output hubVnetName string = hubVnet.name
output hubVnetId string = hubVnet.id
output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output logAnalyticsWorkspaceId string = logAnalytics.id
output logAnalyticsCustomerId string = logAnalytics.properties.customerId
output flowLogStorageId string = flowLogStorage.id
output networkWatcherName string = networkWatcher.name
