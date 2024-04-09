param location string = 'northeurope'
param resourcePrefix string = 'xftest9'
param storageAccountName string = '${resourcePrefix}storage'
param fileShareName string = '${resourcePrefix}fileshare'
param environmentName string = '${resourcePrefix}env'
param environmentStorageName string = '${resourcePrefix}envstorage'
param acaName string = '${resourcePrefix}aca'
param volumeName string = '${resourcePrefix}volume'
param acaJobName string = '${resourcePrefix}acajob'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  name: storageAccountName
  location: location
  tags: {}
  properties: {
    allowCrossTenantReplication: false
    minimumTlsVersion: 'TLS1_0'
    allowBlobPublicAccess: false
    largeFileSharesState: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

resource defaultFileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    protocolSettings: {
      smb: {}
    }
    cors: {
      corsRules: []
    }
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: defaultFileService
  name: fileShareName
}

param containerAppLogAnalyticsName string = '${resourcePrefix}-log'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: containerAppLogAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource environment 'Microsoft.App/managedEnvironments@2023-11-02-preview' = {
  name: environmentName
  location: location
  properties: {
    daprAIInstrumentationKey: null
    daprAIConnectionString: null
    vnetConfiguration: null
    openTelemetryConfiguration: null
    zoneRedundant: false
    customDomainConfiguration: {
      dnsSuffix: null
      certificateKeyVaultProperties: null
      certificateValue: null
      certificatePassword: null
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    workloadProfiles: [
      {
        workloadProfileType: 'Consumption'
        name: 'Consumption'
      }
      {
        workloadProfileType: 'NC24-A100'
        name: 'GPU'
        minimumCount: 1
        maximumCount: 1
      }
    ]
    appInsightsConfiguration: null
    infrastructureResourceGroup: null
    peerAuthentication: {
      mtls: {
        enabled: false
      }
    }
  }
}

resource envStorage 'Microsoft.App/managedEnvironments/storages@2023-11-02-preview' = {
  parent: environment
  name: environmentStorageName
  properties: {
    azureFile: {
      accountName: storageAccount.name
      accountKey: storageAccount.listKeys().keys[0].value
      shareName: fileShare.name
      accessMode: 'ReadWrite'
    }
  }
}

resource acajob 'Microsoft.App/jobs@2023-11-02-preview' = {
  name: acaJobName
  location: location
  properties: {
    environmentId: environment.id
    workloadProfileName: 'GPU'
    configuration: {
      secrets: null
      triggerType: 'Manual'
      replicaTimeout: 1800
      replicaRetryLimit: 0
      manualTriggerConfig: {
        replicaCompletionCount: 1
        parallelism: 1
      }
      scheduleTriggerConfig: null
      eventTriggerConfig: null
      registries: null
    }
    template: {
      containers: [
        {
          image: 'docker.io/huggingface/transformers-all-latest-gpu'
          name: acaJobName
          command: [
            '/bin/bash'
            '-c'
            'cd /mount; git clone https://github.com/XiaofuHuang/windows-ai-studio-templates.git; cd /mount/windows-ai-studio-templates/configs/phi-1_5; pip install -r ./setup/requirements.txt; git lfs install; git clone https://huggingface.co/microsoft/phi-1_5; python3 ./finetuning/invoke_olive.py'
          ]
          resources: {
            cpu: 24
            memory: '220Gi'
          }
          volumeMounts: [
            {
              volumeName: volumeName
              mountPath: '/mount'
            }
          ]
        }
      ]
      initContainers: null
      volumes: [
        {
          name: volumeName
          storageType: 'AzureFile'
          storageName: envStorage.name
        }
      ]
    }
  }
  identity: {
    type: 'None'
  }
}


// resource aca 'Microsoft.App/containerApps@2023-11-02-preview' = {
//   name: acaName
//   location: location
//   properties: {
//     environmentId: environment.id
//     workloadProfileName: 'GPU'
//     configuration: {
//       secrets: null
//       activeRevisionsMode: 'Single'
//       ingress: null
//       registries: null
//       dapr: null
//       maxInactiveRevisions: 100
//       service: null
//     }
//     template: {
//       revisionSuffix: ''
//       terminationGracePeriodSeconds: null
//       containers: [
//         {
//           image: 'docker.io/huggingface/transformers-all-latest-gpu'
//           name: 'finetune-aca-file'
//           command: [
//             '/bin/bash'
//             '-c'
//             'cd /mount; git clone https://github.com/XiaofuHuang/windows-ai-studio-templates.git; cd /mount/windows-ai-studio-templates/configs/phi-1_5; pip install -r ./setup/requirements.txt; git lfs install; git clone https://huggingface.co/microsoft/phi-1_5; python3 ./finetuning/invoke_olive.py'
//           ]
//           resources: {
//             cpu: 24
//             memory: '220Gi'
//           }
//           probes: []
//           volumeMounts: [
//             {
//               volumeName: volumeName
//               mountPath: '/mount'
//             }
//           ]
//         }
//       ]
//       initContainers: null
//       scale: {
//         minReplicas: 0
//         maxReplicas: 1
//         rules: null
//       }
//       volumes: [
//         {
//           name: volumeName
//           storageType: 'AzureFile'
//           storageName: envStorage.name
//         }
//       ]
//       serviceBinds: null
//     }
//   }
//   identity: {
//     type: 'None'
//   }
// }

output endpoint string = acajob.properties.eventStreamEndpoint
