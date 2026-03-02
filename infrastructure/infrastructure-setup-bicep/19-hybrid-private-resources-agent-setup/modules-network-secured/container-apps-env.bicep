/*
  Container Apps Environment (Dedicated/Workload Profiles) + ACR + Managed Identity
  - Deploys into a /23 subnet with Microsoft.App/environments delegation
  - Internal only (no public ingress)
  - Dedicated D4 workload profile
  - ACR (Basic SKU) with managed identity for pull
*/

@description('Azure region for the deployment')
param location string

@description('Unique suffix for resource naming')
param suffix string

@description('Subnet resource ID for the Container Apps Environment')
param containerAppsSubnetId string

@description('Log Analytics workspace customer ID')
param logAnalyticsCustomerId string

// ---- ACR ----
var acrName = toLower('mcpacr${suffix}')

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}

// ---- User-Assigned Managed Identity ----
resource mcpIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mcp-identity'
  location: location
}

// ---- AcrPull Role Assignment ----
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, mcpIdentity.id, '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: mcpIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// ---- Container Apps Environment (Dedicated) ----
resource containerAppsEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'cae-${suffix}'
  location: location
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: containerAppsSubnetId
      internal: true
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsCustomerId
      }
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
      {
        name: 'Dedicated-D4'
        workloadProfileType: 'D4'
        minimumCount: 1
        maximumCount: 3
      }
    ]
  }
}

// ---- Outputs ----
output containerAppsEnvId string = containerAppsEnv.id
output containerAppsEnvName string = containerAppsEnv.name
output containerAppsEnvDefaultDomain string = containerAppsEnv.properties.defaultDomain
output containerAppsEnvStaticIp string = containerAppsEnv.properties.staticIp
output acrName string = acr.name
output acrLoginServer string = acr.properties.loginServer
output mcpIdentityId string = mcpIdentity.id
output mcpIdentityClientId string = mcpIdentity.properties.clientId
output mcpIdentityPrincipalId string = mcpIdentity.properties.principalId
