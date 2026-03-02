/*
Virtual Network Module
This module deploys the core network infrastructure with security controls:

1. Address Space:
   - VNet CIDR: 172.16.0.0/16 OR 192.168.0.0/16
   - Agents Subnet: 172.16.0.0/24 OR 192.168.0.0/24 (reserved for Azure AI Foundry)
   - Private Endpoint Subnet: 172.16.1.0/24 OR 192.168.1.0/24
   - MCP Subnet: 172.16.2.0/24 OR 192.168.2.0/24 (for user Container Apps)
   - Container Apps Subnet: /23 (for dedicated Container Apps Environment)

2. Security Features:
   - Network isolation
   - Subnet delegation
   - Private endpoint subnet
*/

@description('Azure region for the deployment')
param location string

@description('The name of the virtual network')
param vnetName string = 'agents-vnet-test'

@description('The name of Agents Subnet')
param agentSubnetName string = 'agent-subnet'

@description('The name of Hub subnet')
param peSubnetName string = 'pe-subnet'

@description('The name of MCP subnet for user-deployed Container Apps')
param mcpSubnetName string = 'mcp-subnet'

@description('The name of Container Apps Environment subnet')
param containerAppsSubnetName string = 'container-apps-subnet'

@description('Address space for the VNet')
param vnetAddressPrefix string = ''

@description('Address prefix for the agent subnet')
param agentSubnetPrefix string = ''

@description('Address prefix for the private endpoint subnet')
param peSubnetPrefix string = ''

@description('Address prefix for the MCP subnet')
param mcpSubnetPrefix string = ''

@description('Address prefix for the Container Apps subnet (minimum /23)')
param containerAppsSubnetPrefix string = ''

@description('Route table resource ID to attach to agent and mcp subnets (optional)')
param routeTableId string = ''

var defaultVnetAddressPrefix = '192.168.0.0/16'
var vnetAddress = empty(vnetAddressPrefix) ? defaultVnetAddressPrefix : vnetAddressPrefix
var agentSubnet = empty(agentSubnetPrefix) ? cidrSubnet(vnetAddress, 24, 0) : agentSubnetPrefix
var peSubnet = empty(peSubnetPrefix) ? cidrSubnet(vnetAddress, 24, 1) : peSubnetPrefix
var mcpSubnet = empty(mcpSubnetPrefix) ? cidrSubnet(vnetAddress, 24, 2) : mcpSubnetPrefix
var containerAppsSubnet = empty(containerAppsSubnetPrefix) ? cidrSubnet(vnetAddress, 24, 4) : containerAppsSubnetPrefix

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddress
      ]
    }
    subnets: [
      {
        name: agentSubnetName
        properties: {
          addressPrefix: agentSubnet
          routeTable: !empty(routeTableId) ? { id: routeTableId } : null
          delegations: [
            {
              name: 'Microsoft.app/environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: peSubnetName
        properties: {
          addressPrefix: peSubnet
        }
      }
      {
        name: mcpSubnetName
        properties: {
          addressPrefix: mcpSubnet
          routeTable: !empty(routeTableId) ? { id: routeTableId } : null
          delegations: [
            {
              name: 'Microsoft.App/environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: containerAppsSubnetName
        properties: {
          addressPrefix: containerAppsSubnet
          routeTable: !empty(routeTableId) ? { id: routeTableId } : null
          delegations: [
            {
              name: 'Microsoft.App/environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
    ]
  }
}
// Output variables
output peSubnetName string = peSubnetName
output agentSubnetName string = agentSubnetName
output mcpSubnetName string = mcpSubnetName
output containerAppsSubnetName string = containerAppsSubnetName
output agentSubnetId string = '${virtualNetwork.id}/subnets/${agentSubnetName}'
output peSubnetId string = '${virtualNetwork.id}/subnets/${peSubnetName}'
output mcpSubnetId string = '${virtualNetwork.id}/subnets/${mcpSubnetName}'
output containerAppsSubnetId string = '${virtualNetwork.id}/subnets/${containerAppsSubnetName}'
output virtualNetworkName string = virtualNetwork.name
output virtualNetworkId string = virtualNetwork.id
output virtualNetworkResourceGroup string = resourceGroup().name
output virtualNetworkSubscriptionId string = subscription().subscriptionId
