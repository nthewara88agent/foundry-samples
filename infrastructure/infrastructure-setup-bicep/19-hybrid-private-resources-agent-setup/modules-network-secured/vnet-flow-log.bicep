/*
VNet Flow Log Module
--------------------
Creates a VNet flow log with traffic analytics.
Reusable for any VNet — call once per VNet.
*/

@description('Azure region for the deployment')
param location string

@description('Name for this flow log resource')
param flowLogName string

@description('Resource ID of the target VNet')
param targetVnetId string

@description('Resource ID of the storage account for flow log retention')
param storageAccountId string

@description('Resource ID of the Log Analytics workspace')
param logAnalyticsWorkspaceId string

@description('Log Analytics workspace GUID (customerId)')
param logAnalyticsCustomerId string

@description('Name of the Network Watcher (must exist)')
param networkWatcherName string

resource networkWatcher 'Microsoft.Network/networkWatchers@2024-05-01' existing = {
  name: networkWatcherName
}

resource flowLog 'Microsoft.Network/networkWatchers/flowLogs@2024-05-01' = {
  parent: networkWatcher
  name: flowLogName
  location: location
  properties: {
    targetResourceId: targetVnetId
    storageId: storageAccountId
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
        workspaceResourceId: logAnalyticsWorkspaceId
        workspaceRegion: location
        workspaceId: logAnalyticsCustomerId
        trafficAnalyticsInterval: 10
      }
    }
  }
}
