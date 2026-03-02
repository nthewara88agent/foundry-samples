/*
VNet Peering Module (reusable)
------------------------------
Creates a bidirectional peering between two VNets.
*/

@description('Name of the local VNet')
param localVnetName string

@description('Name of the remote VNet')
param remoteVnetName string

@description('Resource ID of the remote VNet')
param remoteVnetId string

@description('Allow gateway transit from local VNet')
param allowGatewayTransit bool = false

@description('Use remote gateways from local VNet')
param useRemoteGateways bool = false

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  name: '${localVnetName}/${localVnetName}-to-${remoteVnetName}'
  properties: {
    remoteVirtualNetwork: { id: remoteVnetId }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: allowGatewayTransit
    useRemoteGateways: useRemoteGateways
  }
}
