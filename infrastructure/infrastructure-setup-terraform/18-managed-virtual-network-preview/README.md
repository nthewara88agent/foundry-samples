# AI Foundry with Managed VNet - Terraform

This Terraform configuration deploys an Azure AI Foundry environment with complete private networking and Entra ID authentication, including:

- Virtual Network with 3 subnets (private endpoints, VMs, Azure Bastion)
- **Azure Bastion Standard** with tunneling, file copy, and IP connect features
- **Windows Server 2025 VM with Entra ID authentication** (no local password required)
- 7 Private DNS Zones for complete private connectivity
- **Azure AI Foundry with Project-level Capability Host** for Agents workloads
- Storage Account, Cosmos DB, and AI Search with private endpoints
- **Managed Virtual Network V2 with outbound rules** for secure agent connectivity
- Role assignments with RBAC and ABAC conditions for secure access

> **Note:** All resources (including the resource group) are created by Terraform and controlled via feature flags. Networking, storage, Cosmos DB, AI Search, DNS, and VM/Bastion can each be independently enabled or disabled.

## Prerequisites

- Azure subscription
- Terraform >= 1.0
- AzureRM provider ~> 4.0 and AzAPI provider ~> 2.0
- Azure CLI installed and authenticated (`az login`)
- Appropriate Azure RBAC permissions to create resources

## Configuration

1. Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your values:
   - Subscription ID
   - Resource group name prefix and location
   - Feature flags to enable/disable optional resources
   - Network configuration (if networking is enabled)
   - VM credentials (if VM is enabled)

3. Review the variables in `variables.tf` for additional customization options.

## Deployment

### Initial Deployment

1. **Initialize Terraform:**
   ```bash
   terraform init
   ```

2. **Review the planned changes:**
   ```bash
   terraform plan -out=tfplan
   ```

3. **Apply the configuration:**
   ```bash
   terraform apply tfplan
   ```

   The deployment will create:
   - Virtual Network and subnets
   - Private DNS zones
   - Storage Account, Cosmos DB, AI Search
   - AI Foundry account with managed network
   - Private endpoints for all services
   - Windows VM with Entra ID authentication
   - Azure Bastion Standard
   - **Project Capability Host** with proper role assignments

### Updating Existing Infrastructure

If you already have infrastructure deployed and want to add the new features:

1. **Review changes:**
   ```bash
   terraform plan -out=tfplan
   ```

2. **Apply updates:**
   ```bash
   terraform apply tfplan
   ```

   **Expected Changes:**
   - **VM Update**: Adds system-assigned identity and Entra ID extension (no VM replacement)
   - **Bastion Upgrade**: Changes from Basic to Standard SKU (~6 minutes)
   - **New Resources**: 
     - Project Capability Host
     - Cosmos DB Operator role assignment
     - Storage Blob Data Owner role (with ABAC condition)
     - Cosmos DB Built-in Data Contributor role
     - Virtual Machine Administrator Login role
     - AADLoginForWindows VM extension

3. **Important Notes:**
   - ⚠️ **VM Size Changes**: If changing VM size, ensure it's compatible (same resource disk configuration)
   - ⚠️ **Bastion Upgrade**: Upgrading Bastion from Basic to Standard takes ~6 minutes
   - ✅ **No Downtime**: VM remains running during identity and extension installation
   - ✅ **Role Propagation**: Role assignments may take 5-10 minutes to take effect

## Post-Deployment Configuration

### Verify Capability Host Configuration

The deployment automatically configures the AI Foundry Project Capability Host with:
- **Storage Connections**: Links to Azure Storage Account
- **Thread Storage Connections**: Links to Cosmos DB for conversation history
- **Vector Store Connections**: Links to AI Search for vector storage

Verify in Azure Portal:
1. Navigate to AI Foundry resource
2. Go to **Projects** > **firstProject**
3. Check **Capability Hosts** section
4. Verify connections are configured

### Role Assignments Summary

The following roles are automatically assigned:

**Before Capability Host Creation:**
- ✅ Storage Blob Data Contributor (Project → Storage)
- ✅ Search Index Data Contributor (Project → AI Search)
- ✅ Search Service Contributor (Project → AI Search)
- ✅ Cosmos DB Account Reader Role (Project → Cosmos DB)
- ✅ **Cosmos DB Operator** (Project → Cosmos DB) - *Required for capability host*

**After Capability Host Creation:**
- ✅ **Storage Blob Data Owner** (Project → Storage) - *With ABAC condition for agent containers*
- ✅ **Cosmos DB Built-in Data Contributor** (Project → Cosmos DB) - *For thread storage*

**VM Access:**
- ✅ **Virtual Machine Administrator Login** (Current User → VM)

### Additional Outbound Rules (Optional)

If you need additional managed VNet outbound rules (e.g., for Cosmos DB or AI Search), configure them using Azure CLI:

**For Cosmos DB:**
```bash
COSMOS_ID=$(terraform output -raw cosmos_account_id)
AI_FOUNDRY_NAME=$(terraform output -raw ai_foundry_name)
RG_NAME=$(terraform output -raw resource_group_name)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

az rest --method PUT \
  --uri "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.CognitiveServices/accounts/${AI_FOUNDRY_NAME}/managedNetworks/default/outboundRules/cosmos-pe-rule?api-version=2025-10-01-preview" \
  --body '{
    "properties": {
      "type": "PrivateEndpoint",
      "destination": {
        "serviceResourceId": "'${COSMOS_ID}'",
        "subresourceTarget": "Sql"
      },
      "category": "UserDefined"
    }
  }'
```

**For AI Search:**
```bash
SEARCH_ID=$(terraform output -raw aisearch_id)

az rest --method PUT \
  --uri "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.CognitiveServices/accounts/${AI_FOUNDRY_NAME}/managedNetworks/default/outboundRules/search-pe-rule?api-version=2025-10-01-preview" \
  --body '{
    "properties": {
      "type": "PrivateEndpoint",
      "destination": {
        "serviceResourceId": "'${SEARCH_ID}'",
        "subresourceTarget": "searchService"
      },
      "category": "UserDefined"
    }
  }'
```

**Note:** The storage outbound rule is already created by Terraform. Additional rules are only needed for specific scenarios.

## Connecting to the VM

### Option 1: Azure Portal with Entra ID (Recommended)

1. Navigate to the Azure Portal
2. Go to the Windows VM resource
3. Click **Connect** > **Bastion**
4. **Authentication Type**: Select **"Entra ID"** (previously Azure AD)
5. Click **Connect**
6. You'll be authenticated using your current Entra ID credentials
7. No username/password required!

### Option 2: Native RDP Client with Bastion Tunneling

```powershell
# Get VM resource ID
$vmId = $(terraform output -raw windows_vm_id)
$bastionName = $(terraform output -raw bastion_id | Split-Path -Leaf)
$rgName = $(terraform output -raw resource_group_name)

# Create tunnel
az network bastion tunnel `
  --name $bastionName `
  --resource-group $rgName `
  --target-resource-id $vmId `
  --resource-port 3389 `
  --port 3389

# In another terminal, connect with your Entra ID credentials
mstsc /v:localhost:3389
```

### Option 3: Traditional Username/Password (Fallback)

If you need to use the local admin account:
1. Click **Connect** > **Bastion**
## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Virtual Network                        │
│                    10.0.0.0/16                          │
│                                                          │
│  ┌────────────────────────────────────────────┐        │
│  │  Private Endpoints Subnet (10.0.1.0/24)   │        │
│  │  - AI Foundry Private Endpoint             │        │
│  │  - Storage Blob Private Endpoint           │        │
│  │  - Storage File Private Endpoint           │        │
│  │  - Storage Table Private Endpoint          │        │
│  │  - Storage Queue Private Endpoint          │        │
│  │  - Cosmos DB Private Endpoint              │        │
│  │  - AI Search Private Endpoint              │        │
│  └────────────────────────────────────────────┘        │
│                                                          │
│  ┌────────────────────────────────────────────┐        │
│  │  VM Subnet (10.0.2.0/24)                  │        │
│  │  - Windows Server 2025 VM                 │        │
│  │    + System Managed Identity              │        │
│  │    + AADLoginForWindows Extension         │        │
│  │    + No Public IP                         │        │
│  └────────────────────────────────────────────┘        │
│                                                          │
│  ┌────────────────────────────────────────────┐        │
│  │  Azure Bastion Subnet (10.0.3.0/26)       │        │
│  │  - Azure Bastion Standard                 │        │
│  │    + Tunneling Enabled                    │        │
│  │    + File Copy Enabled                    │        │
│  │    + IP Connect Enabled                   │        │
│  └────────────────────────────────────────────┘        │
│                                                          │
└─────────────────────────────────────────────────────────┘
                        │
                        │ Private Endpoints
                        ▼
        ┌───────────────────────────────┐
        │   Azure AI Foundry            │
        │   + System Managed Identity   │
        │   + Managed Network V2        │
        │   + Project: firstProject     │
        │     - Capability Host         │
        │     - Storage Connection      │
        │     - Cosmos DB Connection    │
        │     - AI Search Connection    │
        └───────────────────────────────┘
                        │
                        │ Managed Outbound (PE)
                        ▼
        ┌───────────────────────────────┐
        │   Storage Account             │
        │   (Private Access Only)       │
        │   + Blob, File, Table, Queue  │
        └───────────────────────────────┘
                        
        ┌───────────────────────────────┐
        │   Cosmos DB for NoSQL         │
        │   (Thread Storage)            │
        └───────────────────────────────┘
        
        ┌───────────────────────────────┐
        │   AI Search                   │
        │   (Vector Store)              │
        └───────────────────────────────┘
```

## Key Features Comparison

| Feature | Basic Setup | This Configuration |
|---------|-------------|-------------------|
| VM Authentication | Local Password | ✅ **Entra ID** |
| Bastion SKU | Basic | ✅ **Standard** |
| File Copy via Bastion | ❌ | ✅ |
| Native RDP Tunnel | ❌ | ✅ |
| Capability Host Level | Account | ✅ **Project** |
| Connection References | Generic | ✅ **Explicit** |
| Cosmos DB RBAC | Account Reader | ✅ **+ Operator + Built-in Contributor** |
| Storage RBAC | Blob Contributor | ✅ **+ Blob Owner (ABAC)** |
| Agent Workloads | Not Ready | ✅ **Ready** |


## Files

- `providers.tf` - Provider configuration (AzureRM ~> 4.0, AzAPI ~> 2.0, Random ~> 3.0)
- `variables.tf` - Input variables and feature flags
- `main.tf` - Random suffix, data sources, locals, and resource group
- `network.tf` - VNet, subnets, Bastion, VM, and Entra ID configuration
- `dns.tf` - Private DNS zones and VNet links
- `storage.tf` - Storage account and private endpoints (blob, file, table, queue)
- `cosmos.tf` - Cosmos DB account and private endpoint
- `aisearch.tf` - AI Search service and private endpoint
- `ai-foundry.tf` - AI Foundry account, project, managed network, capability host, connections, and RBAC
- `outputs.tf` - Output values for resource IDs, names, and endpoints
- `terraform.tfvars.example` - Example variable values

## Notes

- **Capability Host Architecture**: Uses project-level capability host matching Bicep template
- **Workspace ID Formatting**: Automatically extracts and formats project workspace ID for ABAC conditions
- **Entra ID Authentication**: VM configured with AADLoginForWindows extension
- **Role Assignment Timing**: 
  - Cosmos DB Operator must be assigned **before** capability host creation
  - Storage Blob Data Owner and Cosmos Built-in Contributor assigned **after**
- **ABAC Conditions**: Storage role includes condition for agent-specific containers
- **Bastion Features**: Standard SKU required for tunneling and file copy
- **VM Size Compatibility**: Changing VM sizes requires same resource disk configuration
- **Role Propagation**: RBAC assignments may take 5-10 minutes to fully propagate
- **Managed Network**: Uses Managed Virtual Network V2 with AllowInternetOutbound isolation mode
- **Resource Naming**: All resource names include a random hex suffix (via `random_id`) for uniqueness

## Known Issues

### Destroy operation fails with Managed Virtual Network

There is a known issue when running `terraform destroy` on deployments that use the Managed Virtual Network V2 configuration. The AI Foundry managed network creates internal `serviceAssociationLinks` on agent subnets that are not automatically cleaned up during destroy, which can cause errors such as:

- `InUseSubnetCannotBeDeleted` — the agent subnet delegation cannot be removed because the managed network still holds a service association link
- Dependent resources may time out waiting for the AI Foundry account deletion to fully propagate

**Workaround:** After a failed destroy, wait 10-15 minutes for Azure to release the service association links, then purge the soft-deleted cognitive account manually before retrying:

```bash
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
LOCATION="<your-location>"
RG_NAME="<your-resource-group-name>"
FOUNDRY_NAME="<your-foundry-account-name>"

az rest --method DELETE \
  --uri "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/providers/Microsoft.CognitiveServices/locations/${LOCATION}/resourceGroups/${RG_NAME}/deletedAccounts/${FOUNDRY_NAME}?api-version=2021-04-30"
```

Then re-run `terraform destroy`.

## Troubleshooting

### VM Size Change Error
**Error**: "Unable to resize the VM since changing from resource disk to non-resource disk VM size and vice-versa is not allowed"

**Solution**: Choose a VM size in the same family:
- From `Standard_B2s` → Use `Standard_B*s` series
- From `Standard_D*s_v5` → Use other D-series v5 SKUs
- Or deallocate, delete, and recreate the VM

### Entra ID Login Not Working
1. Verify AADLoginForWindows extension is installed:
   ```bash
   az vm extension list --resource-group <rg> --vm-name <vm-name>
   ```
2. Check role assignment exists:
   ```bash
   az role assignment list --assignee <your-user-id> --scope <vm-id>
   ```
3. Wait 5-10 minutes for role propagation

### Capability Host Connection Issues
1. Verify connections exist in Azure Portal: AI Foundry → Projects → Connections
2. Check role assignments are complete:
   ```bash
   terraform output
   az role assignment list --scope <storage-id>
   ```
3. Ensure Cosmos DB Operator role was assigned before capability host creation

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Confirm by typing `yes` when prompted.

> ⚠️ **See [Known Issues](#known-issues) above** — the destroy operation may fail due to managed network service association links. Follow the workaround if you encounter `InUseSubnetCannotBeDeleted` errors.

## Security Considerations

- All PaaS services have public network access disabled
- VM has no public IP address - access only via Bastion
- Storage account is only accessible via private endpoints
- AI Foundry uses managed network with controlled outbound rules
- All DNS resolution happens via private DNS zones
- Managed identity with RBAC for service-to-service authentication
- Local authentication disabled on the AI Foundry account (`disableLocalAuth = true`)
