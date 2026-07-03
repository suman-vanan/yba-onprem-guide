# Scalability

## Horizontal Scaling

YugabyteDB supports online horizontal scaling, annd can scale seamlessly while running a read-write workload.

Before you can scale your universe in YBA, you need to ensure that your in-use provider has spare instances that are available for use.

The preferred approach is to complete [step 8 (Provision Database Nodes (Node Agent Method)](../README.md) for the additional VM that will be used when scaling-out the universe.

Once that is done, you should be able to see the unused instance in the YBA UI: Integrations > Infrastructure > On-Premises Datacenters > Instances.

After verifying the above, you may follow [this guide](https://docs.yugabyte.com/stable/explore/linear-scalability/scaling-universe-yba/#add-a-node) to scale out your universe.

## Vertical Scaling

Vertical scaling for on-premise universes is also an online operation. DB nodes will need to be restarted via a rolling restart to ensure that the cluster is available during the entire scale up process.

The typical steps are as follows:
- Sysadmin for the VMs used as DB nodes to allocate more resources (CPU, Memory, or Disk)
- If this is "Hot Add", then the VM does not need to be rebooted. Instead, we merely need to restart the database processes via a rolling restart (YBA UI > Your Universe > Actions > Initiate Rolling Restart)
- If the VM needs to be rebooted in order to scale up the relevant resource(s), then the VMs should be restarted in a rolling restart manner. After each VM restart, verify that the scale up is successful.