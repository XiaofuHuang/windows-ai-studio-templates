param location string = 'northeurope'
param resourcePrefix string = 'xftest7'
param storageAccountName string = '${resourcePrefix}storage'
param fileShareName string = '${resourcePrefix}fileshare'
param environmentName string = '${resourcePrefix}env'
param environmentStorageName string = '${resourcePrefix}envstorage'
param acaName string = '${resourcePrefix}aca'
param volumeName string = '${resourcePrefix}volume'

@description('Generated from /subscriptions/1756abc0-3554-4341-8d6a-46674962ea19/resourceGroups/aca_gpu_xiaofhua/providers/Microsoft.Storage/storageAccounts/filescreatedbycli')
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

@description('Generated from /subscriptions/1756abc0-3554-4341-8d6a-46674962ea19/resourceGroups/aca_gpu_xiaofhua/providers/Microsoft.Storage/storageAccounts/filescreatedbycli/fileServices/default')
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

@description('Generated from /subscriptions/1756abc0-3554-4341-8d6a-46674962ea19/resourceGroups/aca_gpu_xiaofhua/providers/Microsoft.App/managedEnvironments/managedEnvironment-acagpuxiaofhua-822b')
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

@description('Generated from /subscriptions/1756abc0-3554-4341-8d6a-46674962ea19/resourceGroups/aca_gpu_xiaofhua/providers/Microsoft.App/managedEnvironments/managedEnvironment-acagpuxiaofhua-822b/storages/mystoragemount')
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

@description('Generated from /subscriptions/1756abc0-3554-4341-8d6a-46674962ea19/resourceGroups/aca_gpu_xiaofhua/providers/Microsoft.App/containerapps/finetune-aca-file')
resource containerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: acaName
  location: location
  properties: {
    environmentId: environment.id
    workloadProfileName: 'GPU'
    configuration: {
      secrets: null
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 80
        exposedPort: 0
        transport: 'Auto'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        customDomains: null
        allowInsecure: true
        ipSecurityRestrictions: null
        corsPolicy: {
          allowedOrigins: [
            '*'
          ]
          allowedMethods: [
            '*'
          ]
          allowedHeaders: [
            '*'
          ]
          exposeHeaders: null
          maxAge: 0
          allowCredentials: true
        }
        clientCertificateMode: 'Ignore'
        stickySessions: {
          affinity: 'none'
        }
        additionalPortMappings: null
        targetPortHttpScheme: null
      }
      registries: null
      dapr: null
      maxInactiveRevisions: 100
      service: null
    }
    template: {
      revisionSuffix: ''
      terminationGracePeriodSeconds: null
      containers: [
        {
          image: 'docker.io/huggingface/transformers-all-latest-gpu'
          name: 'finetune-aca-file'
          command: [
            '/bin/bash'
            '-c'
            'apt-get install -y curl; /mount/server/test.sh; /root/.vscode-server-insiders/bin/2af613979f646fc4dcebfeaedc7d14f138c7b072/bin/code-server-insiders --start-server --host=0.0.0. --accept-server-license-terms --without-connection-token --telemetry-level all --port=80  --install-extension ms-python.python  --install-extension ms-toolsai.jupyter'
          ]
          // /bin/bash, -c, apt-get install -y curl; cd /mount/windows-ai-studio-templates/configs/phi-1_5; pip install -r ./setup/requirements.txt; python3 ./finetuning/invoke_olive.py
          resources: {
            cpu: 24
            memory: '220Gi'
          }
          // resources: {
          //   cpu: 4
          //   memory: '8Gi'
          // }
          probes: [
            {
              type: 'Liveness'
              failureThreshold: 3
              httpGet: {
                path: '/version'
                port: 80
                scheme: 'HTTP'
              }
              initialDelaySeconds: 60
              periodSeconds: 10
              successThreshold: 1
              timeoutSeconds: 1
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/version'
                port: 80
                scheme: 'HTTP'
              }
              initialDelaySeconds: 60
              periodSeconds: 10
            }
            {
              type: 'Startup'
              httpGet: {
                path: '/version'
                port: 80
                scheme: 'HTTP'
              }
              initialDelaySeconds: 60
              periodSeconds: 10
            }
          ]
          volumeMounts: [
            {
              volumeName: volumeName
              mountPath: '/mount'
            }
          ]
        }
      ]
      initContainers: null
      scale: {
        minReplicas: 1
        maxReplicas: 1
        rules: null
      }
      volumes: [
        {
          name: volumeName
          storageType: 'AzureFile'
          storageName: envStorage.name
        }
      ]
      serviceBinds: null
    }
  }
  identity: {
    type: 'None'
  }
}
