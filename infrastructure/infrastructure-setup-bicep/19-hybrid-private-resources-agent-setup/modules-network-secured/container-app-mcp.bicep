/*
  MCP Server Container App
  - Runs on dedicated workload profile
  - Internal-only ingress on port 8080
  - Uses managed identity for ACR pull
  
  NOTE: The container image must be imported into ACR before deploying this module.
  Post-deployment step:
    az acr import --name <acrName> \
      --source retrievaltestacr.azurecr.io/multi-auth-mcp/api-multi-auth-mcp-env:latest \
      --image multi-auth-mcp:latest
*/

@description('Azure region for the deployment')
param location string

@description('Unique suffix for resource naming')
param suffix string

@description('Container Apps Environment resource ID')
param containerAppsEnvId string

@description('ACR login server (e.g., myacr.azurecr.io)')
param acrLoginServer string

@description('User-Assigned Managed Identity resource ID')
param mcpIdentityId string

@description('User-Assigned Managed Identity client ID')
param mcpIdentityClientId string

var imageName = '${acrLoginServer}/multi-auth-mcp:latest'

resource mcpApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'mcp-server-${suffix}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${mcpIdentityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvId
    workloadProfileName: 'Dedicated-D4'
    configuration: {
      ingress: {
        external: false
        targetPort: 8080
        transport: 'auto'
      }
      registries: [
        {
          server: acrLoginServer
          identity: mcpIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'mcp-server'
          image: imageName
          resources: {
            cpu: json('2.0')
            memory: '4Gi'
          }
          env: [
            {
              name: 'AZURE_CLIENT_ID'
              value: mcpIdentityClientId
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
}

output mcpAppName string = mcpApp.name
output mcpAppFqdn string = mcpApp.properties.configuration.ingress.fqdn
