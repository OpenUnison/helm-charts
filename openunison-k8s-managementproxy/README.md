# OpenUnison Management Proxy

![OpenUnison Management Proxy](https://raw.githubusercontent.com/OpenUnison/openunison-k8s-managementproxy/main/imgs/openunison_qs_kubernetes.png)

The management proxy exposes a cluster's API server without having to get the cluster's Certificate Authority to issue you a certificate, use a static `ServiceAccount`, or require a [3rd party Identity Provider](https://www.tremolosecurity.com/post/pipelines-and-kubernetes-authentication).  The proxy relies on the same security used by API servers that integrate with OpenID Connect, relying on the security of the identity provider.  When deployed with OpenUnison's Orchestra Login Portal, this proxy provides a secure mechanism for multi-cluster self service management.

# Deployment


## What You Need To Start

Prior to deploying Orchestra you will need:

1. Kubernetes 1.10 or higher
2. The Nginx Ingress Controller deployed (https://kubernetes.github.io/ingress-nginx/deploy/)
3. An OIDC issuer discovery URL or a keypair to use
5. helm 3.0+


## Add Tremolo Security's Helm Repo

```
helm repo add tremolo https://nexus.tremolo.io/repository/helm/
helm repo update
```

## Deploy The OpenUnison Operator

Create your namespace
```
kubectl create ns ou-mgmt-proxy
```

Deploy the operator
```
helm install openunison tremolo/openunison-operator --namespace ou-mgmt-proxy
```

Wait for the operator pod to be available
```
watch kubectl get pods -n ou-mgmt-proxy
```

## Create A Secret For Your OpenID Connect Secret

Create a secret in the `openunison` namespace, replace the value of `unisonKeystorePassword` with a base64 encoded random string:

```
apiVersion: v1
type: Opaque
metadata:
  name: orchestra-secrets-source
  namespace: ou-mgmt-proxy
data:
  unisonKeystorePassword: aW0gYSBzZWNyZXQ=
kind: Secret
```

| Property | Description |
| -------- | ----------- |
| unisonKeystorePassword | The password for OpenUnison's keystore, should NOT contain an ampersand (`&`) |


## Optional - Create Keypair

If you don't have an OIDC discovery document available for your pipeline's credentials, you can generate a keypair using openssl and embed the generated certificate into your values.yaml:

```
$ openssl req -x509 -sha256 -nodes -days 3650 -newkey rsa:2048 -keyout privateKey.key -out certificate.crt
```

After answering the questions the `certificate.crt` should be base64 encoded and included in the `trustest_certs` section of your values.yaml.  `privateKey.key` can be used to generate a signed JWT that can be used to make API calls.


## Deploy OpenUnison

Copy `values.yaml` (https://github.com/OpenUnison/helm-charts/blob/master/openunison-k8s-managementproxy/values.yaml) and update as appropriate:

| Property | Description |
| -------- | ----------- |
| services.api_server_host | The host name the proxy will be accessible by.  This host name must be accessible by your Orchestra Portal cluster. |
| services.issuer_url | The URL for Orchestra remote management OpenID Connect identity provider.  Generally `https://orchestrahost/auth/idp/remotek8s` |
| services.enable_tokenrequest | If true, the OpenUnison pods will use the TokenRequestAPI instead of static `ServiceAccount` tokens.  This is a good risk mitigation tool as these tokens expire every ten minutes and are not stored in your cluster's etcd database |
| services.token_request_audience | When using the TokenRequestAPI, the audience to request tokens for. |
| services.token_request_expiration_seconds | Number of seconds tokens are valid, minimum of 600 (10 minutes) |
| services.enable_cluster_admin | if `true` a `ClusterRoleBinding` will be created to make the management proxy cluster admin.  Otherwise an RBAC profile must be created for the proxy's service account.  Defaults to `false` |
| services.issuer_from_well_known | if `true`, `services.issuer_url` must have an OIDC discovery document at `/.well-known/openid-configuration`.  Otherwise, `services.issuer_certificate_alias` must be set and an isser certificate must be included in the `trusted_certificates` section.  Default is `true` |
| services.issuer_certificate_alias | if `services.issuer_from_well_known` is `false`, must name the entry in `trusted_certificates` that containers the issuer validation certificate | 
| cert_template.ou | The `OU` attribute for the forward facing certificate |
| cert_template.o | The `O` attribute for the forward facing certificate |
| cert_template.l | The `L` attribute for the forward facing certificate |
| cert_template.st | The `ST` attribute for the forward facing certificate |
| cert_template.c | The `C` attribute for the forward facing certificate |
| certs.use_k8s_cm  | Tells the deployment system if you should use k8s' built in certificate manager.  If your distribution doesn't support this (such as Canonical and Rancher), set this to false |
| image | The name of the image to use |
| monitoring.prometheus_service_account | The prometheus service account to authorize access to the /monitoring endpoint |
| network_policies.enabled | If `true`, the chart will generate `NetworkPolicy` objects that limit access to the OpenUnison pods.  This is a good option to enable to minimize the services in your cluster that can access the OpenUnison pods and their `ServiceAccount` tokens.
| network_policies.ingress.enabled | If `true`, a `NetworkPolicy` is created to allow traffic from the `Ingress` controller's `Namespace`.  If enabling `NetworkPolicy` generation this should be set to `true` |
| network_policies.ingress.labels | List of labels the ingress `Namespace` uses to allow access. |
| network_policies.monitoring.enabled | If `true`, a `NetworkPolicy` is created to allow traffic from the cluster's Prometheus for monitoring.  If enabling `NetworkPolicy` and using Prometheus this should be set to `true` |
| network_policies.monitoring.labels | List of labels the monitoring `Namespace` uses to allow access. ***NOTE*** : By default, the `monitoring` namespace generated by `kube-prometheus` has no labels, so you'll need to add one |


Additionally, you can add your Orchestra Portal's TLS base64 encoded PEM certificate to your values under `trusted_certs` for `pem_b64`.  This will allow OpenUnison to talk to your portal using TLS if it doesn't use a commercially signed certificate.  If you don't need a certificate to talk to your identity provider, replace the `trusted_certs` section with `trusted_certs: []`.

Finally, run the helm chart:

`helm install management-proxy tremolo/openunison-k8s-management --namespace ou-mgmt-proxy -f /path/to/values.yaml`

## Using The Management Proxy From Your Pipeline

In order to use the management proxy, you must generate a JWT that is signed with the private key that is trusted by the issuer public key.  As an example, the below Python code generates a JWT that will work:

```
private_key = open('/path/to/privateKey.key').read()

jwt_claims = {
    'sub': values_json["services"]["issuer_url"],
    'iss': values_json["services"]["issuer_url"],
    'aud':'kubernetes',
    'jti':str(uuid4()),
    'iat':datetime.datetime.utcnow(),
    'exp':datetime.datetime.utcnow() + datetime.timedelta(seconds=int(seconds_to_live)),
    'nbf':datetime.datetime.utcnow() - datetime.timedelta(seconds=60)
}



signed_jwt = jwt.encode(jwt_claims,key=private_key,algorithm='RS256')

token = signed_jwt.decode("utf-8")
```

Make sure that `seconds_to_live` is long enough to complete your pipeline's work, but short enough to expire before it can be abused if compromised.

## Adding The New Cluster to Orchestra

Use the helm chart to add your new cluster to Orchestra.  

