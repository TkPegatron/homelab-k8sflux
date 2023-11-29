# Migrating database by hand

The command run in the bootstrap deployment holds the pod open after completing the initdb tasks, allowing us to import data from a local file using a cli pipe.

This is a simple way of migrating or importing without exsitsting PV backup infrastructure.

**Note:** The execution context for these shell commands is the controller jumpbox or jumppod.

## Exporting from standalone DB

```shell
kubectl exec deployments/netbox-initdb-adhoc -- pg_dump --user netbox netbox \
  | gzip > kubernetes/apps/default/netbox/app/bootstrap/files/netbox-psql-backup.sql.gz

kubectl exec -i deployments/netbox-initdb-adhoc -- /bin/bash -c \
  'PGPASSWORD="${INIT_POSTGRES_SUPER_PASS}" pg_dump --host ${INIT_POSTGRES_HOST} --user postgres netbox'
```

## Importing to CNPG Cluster

**Note:** The variables referenced in the commands below are injected into the pod and do not need to be set on the local shell environment.

```shell
# Apply kustomization from local terminal
kubectl apply --kustomize kubernetes/apps/default/netbox/app/bootstrap

# Import database stored on local machine
zcat kubernetes/applications/default/netbox/app/bootstrap/files/netbox-psql-backup.sql.gz \
  | kubectl exec -i deployments/netbox-initdb-adhoc -- /bin/bash -c \
  'PGPASSWORD="${INIT_POSTGRES_SUPER_PASS}" psql --host ${INIT_POSTGRES_HOST} --user postgres netbox'

# Cleanup resources
kubectl delete --kustomize kubernetes/apps/default/netbox/app/bootstrap
```

## Exporting from CNPG Cluster
