# Lab99

## Arch

Consul Server * 3

Consul Client * 1

Consul Client will not join Cluster at first. We need to use 2 TOKENs to join Consul Cluster. You can see in `lab99/docker-compose.yml:consul-client:command`. I used sleep to overwrite Docker endpoint (stopping Docker starts Consul automatically).

## Purpose

### 1. Test if Consul Servers could become Cluster withoyt master key

You can see lab99/config/server1-3.json. There is no master key assigned. Just only configure enable ACL.

### 2. Using Consul command to generator the following keys:

1. Master Key
2. Agent Token
    acl_agent_token - Used for clients and servers to perform internal operations. If this isn't specified, then the acl_token will be used. This was added in Consul 0.7.2.

    This token must at least have write access to the node name it will register as in order to set any of the node-level information in the catalog such as metadata, or the node's tagged addresses. There are other places this token is used, please see ACL Agent Token (https://www.consul.io/docs/guides/acl.html#acl-agent-token) for more details.
3. Agent Default Token
    When provided, the agent will use this token when making requests to the Consul servers. Clients can override this token on a per-request basis by providing the "?token" query parameter. When not provided, the empty token, which maps to the 'anonymous' ACL policy, is used.

    request token → acl_token → anonymous token

    So in other words, a service registration (whether it is initiated via API call or config file) will either need an explicit token in the API request or in the config file itself as you describe, otherwise it will default to using *acl.tokens.default*.


## Actions

1. Launch Docker Compose
```bash
$ cd lab99
$ docker-compose up
```

2. Login into Consul-Server1

```bash
$ docker exec -it consul-server1 sh

// When execute consul members, you get nothing, becuase you do not have permission to do it.
# consul members

// Create master key (The SecretID)
# consul acl bootstrap
AccessorID:       0f2c6697-36e8-78ef-22be-e519eb851912
SecretID:         d63e7ade-6647-bb82-19fc-394f67ca584a
Description:      Bootstrap Token (Global Management)
Local:            false
Create Time:      2019-08-01 16:30:55.943908995 +0000 UTC
Policies:
   00000000-0000-0000-0000-000000000001 - global-management

// Export master key, then you have root permission
# export CONSUL_HTTP_TOKEN=d63e7ade-6647-bb82-19fc-394f67ca584a
// Afeter using master key, you can check how many members in the Cluster
# consul members

// Create Token policy and create Agent Token
# cd /consul/acl/
/consul/acl # consul acl policy create  -name "agent-token-policy" -description "Agent Token Policy" -rules @agent-token-policy.hcl
ID:           ececbd60-94ba-dcf2-2993-3fab0ccb5690
Name:         agent-token-policy
Description:  Agent Token Policy
Datacenters:
Rules:
node_prefix "" {
   policy = "write"
}

service_prefix "" {
   policy = "read"
}

// Create Agent Token = acl.tokens.agent (SecretID)
/consul/acl # consul acl token create -description "agent token" -policy-name "agent-TOKEN-policy"
AccessorID:       efb8a8ad-f6b2-aa8f-79ee-b673e89ffc34
SecretID:         4083ab09-3b2c-119e-2627-c21c98d1c81f
Description:      agent token
Local:            false
Create Time:      2019-08-01 16:31:24.728251632 +0000 UTC
Policies:
   ececbd60-94ba-dcf2-2993-3fab0ccb5690 - agent-token-policy

// Create Agent Default Policy
/consul/acl # consul acl policy create  -name "agent-default-policy" -description "Agent Default Token Policy" -rules @agent-default-policy.hcl
ID:           8a44fbf3-a6fa-0e4c-0729-531e19dcd704
Name:         agent-default-policy
Description:  Agent Default Token Policy
Datacenters:
Rules:
service_prefix "" {
    policy = "write"
}

// Create Agent Default Token = acl.tokens.default (SecretID)
/consul/acl # consul acl token create -description "agent default token" -policy-name "agent-default-policy"
AccessorID:       d05968db-77aa-9b35-050f-176703c623ea
SecretID:         eed040a8-3430-04c4-3fa5-e4dea4556f8c
Description:      agent default token
Local:            false
Create Time:      2019-08-01 16:31:39.001073097 +0000 UTC
Policies:
   8a44fbf3-a6fa-0e4c-0729-531e19dcd704 - agent-default-policy
```

3. Login to Consul-Client

```bash

// Start Consul Client
// You will get error message here, because you do not have permission to join cluster and sync data
# consul agent --config-dir=/consul/config

// Change acl.tokens.agent and acl.token.default (get key from above commands)
# vi /consul/config/consul.json
{
    "data_dir": "/consul/data",
    "log_level": "INFO",
    "client_addr": "0.0.0.0",
    "retry_join": ["consul-server1"],
    "acl": {
        "tokens": {
            "agent": "4083ab09-3b2c-119e-2627-c21c98d1c81f",
            "default": "eed040a8-3430-04c4-3fa5-e4dea4556f8c"
        }
    }
}

// Start Consul Client
// You can see you started to sync your local service: Batch to Consul Cluster
# consul agent --config-dir=/consul/config

// Check Consul Cluster UI (Trigger ACL tab then use master key, you can login it)
// You can see Batch service is unhealth

// Send heartbeat
# curl -X PUT localhost:8500/v1/agent/check/pass/service:Batch

// Check Consul UI Again
```

Ref:
1. https://github.com/hashicorp/consul/issues/4478
2. https://medium.com/devopslinks/introduction-to-consul-kv-with-acl-183e4dd7ee1c
