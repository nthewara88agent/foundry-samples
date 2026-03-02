/*
Route Table Module
------------------
Creates a UDR with a default route pointing to Azure Firewall.
*/

@description('Azure region for the deployment')
param location string

@description('Name of the route table')
param routeTableName string

@description('Azure Firewall private IP address (next hop)')
param firewallPrivateIp string

resource routeTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: routeTableName
  location: location
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'default-to-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
    ]
  }
}

output routeTableId string = routeTable.id
output routeTableName string = routeTable.name
