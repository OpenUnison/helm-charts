# Adding a Cluster to OpenUnison Orchestra

## Cluster Management

### Management Proxy

### Service Account

### Certificate

### GitOps

#### Cluster Repo

The cluster repository is sued tos tore cluster resources that developers should not have the ability to change.  For instance `Namespace` objects.  When onboarding a new namespace, OpenUnison will write cluster level objects to this repository.

##### Create SSH Keypair

```
ssh-keygen -f ./id_rsa
```

Upload `id_rsa.pub` to your root git repo, make sure to mark the key as able to write to the repo.  Also connect your repo to your cluster using your favorite GitOps system.

Next, create a secret in the `openunison` namespace with your keys with the name `sshkey-cluster-CLUSTER_NAME` where `CLUSTER_NAME` is the name of your cluster defined in `cluster.name` value of your values.yaml for onboarding the cluster to OpenUnison.  For instance if your `cluster.name` is `gitops` you would create the secret with the command (in the same directory you created your keys in):

```
kubectl create secret generic sshkey-cluster-k8s-gitops --from-file=. -n openunison
```

