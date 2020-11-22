# Orchestra Login Portal for OpenID Connect

[![Alt text](https://i.vimeocdn.com/video/735154945_640.webp)](https://vimeo.com/319764476)

*Short video of logging into Kubernetes and using kubectl using OpenID Connect and Keycloak*

Orchestra Login Portal provides a login portal for Kubernetes that allows you to authenticate with your OpenID Connect credentials, use the identity provider's groups for RBAC authorizations and provides integration for both `kubectl` and the Kubernetes Dashboard (https://github.com/kubernetes/dashboard).  The portal runs inside of Kubernetes, leveraging Kubernetes for scalability, secret management and deployment. 

![Orchestra Login Portal Architecture](https://raw.githubusercontent.com/OpenUnison/openunison-k8s-login-oidc/master/imgs/openunison_qs_kubernetes.png)

When a user accesses Kubernetes using Orchestra, they'll access both the login portal and the dashboard through OpenUnison (instead of directly via an ingress).  OpenUnison will inject the user's identity into each request, allowing the dashboard to act on their behalf.  The login portal has no external dependencies outside of your OpenID Connect identity provider and Kubernetes.  All objects for session state are stored as CRDs.

# Deployment


## What You Need To Start

Prior to deploying Orchestra you will need:

1. Kubernetes 1.10 or higher
2. The Nginx Ingress Controller deployed (https://kubernetes.github.io/ingress-nginx/deploy/)
3. Information from your OpenID Connect Identity Provider per *Prepare Deployment* in the next section. When registering OpenUnison with your identity provider, use the hostname and /auth/oidc as the redirect. For instance if OpenUnison will be running on k8sou.tremolo.lan.com then the redirect_uri will be https://k8sou.tremolo.lan/auth/oidc
4. Deploy the dashboard to your cluster
5. helm 3.0+


### Required Attributes for Your Identity Provider

In order to integrate your identity provide make sure the following attributes are in the `id_token`:

* sub
* email
* given_name
* family_name
* name
* groups (optional)

These are then mapped into the user's object in OpenUnison for personalization and authorization.  These attributes are often available with the `profile` scope.

## Add Tremolo Security's Helm Repo

```
helm repo add tremolo https://nexus.tremolo.io/repository/helm/
helm repo update
```

## Deploy The OpenUnison Operator

Create your namespace
```
kubectl create ns openunison
```

Deploy the operator
```
helm install openunison tremolo/openunison-operator --namespace openunison
```

Wait for the operator pod to be available
```
watch kubectl get pods -n openunison
```

## Create A Secret For Your OpenID Connect Secret

Create a secret in the `openunison` namespace:

```
apiVersion: v1
type: Opaque
metadata:
  name: orchestra-secrets-source
  namespace: openunison
data:
  OIDC_CLIENT_SECRET: aW0gYSBzZWNyZXQ=
  K8S_DB_SECRET: aW0gYSBzZWNyZXQ=
  unisonKeystorePassword: aW0gYSBzZWNyZXQ=
kind: Secret
```

| Property | Description |
| -------- | ----------- |
| OIDC_CLIENT_SECRET | The secret provided by your identity provider |
| unisonKeystorePassword | The password for OpenUnison's keystore, should NOT contain an ampersand (`&`) |
| K8S_DB_SECRET | A random string of characters used to secure the SSO process with the dashboard.  This should be long and random, with no ampersands (`&`) |


## Deploy OpenUnison

Copy `values.yaml` (https://raw.githubusercontent.com/OpenUnison/helm-charts/master/openunison-k8s-login-oidc/values.yaml) and update as appropriate:

| Property | Description |
| -------- | ----------- |
| network.openunison_host | The host name for OpenUnison.  This is what user's will put into their browser to login to Kubernetes |
| network.dashboard_host | The host name for the dashboard.  This is what users will put into the browser to access to the dashboard. **NOTE:** `network.openunison_host` and `network.dashboard_host` Both `network.openunison_host` and `network.dashboard_host` **MUST** point to OpenUnison |
| network.api_server_host | The host name to use for the api server reverse proxy.  This is what `kubectl` will interact with to access your cluster. **NOTE:** `network.openunison_host` and `network.dashboard_host` |
| network.k8s_url | The URL for the Kubernetes API server | 
| network.session_inactivity_timeout_seconds | The number of seconds of inactivity before the session is terminated, also the length of the refresh token's session |
| cert_template.ou | The `OU` attribute for the forward facing certificate |
| cert_template.o | The `O` attribute for the forward facing certificate |
| cert_template.l | The `L` attribute for the forward facing certificate |
| cert_template.st | The `ST` attribute for the forward facing certificate |
| cert_template.c | The `C` attribute for the forward facing certificate |
| certs.use_k8s_cm  | Tells the deployment system if you should use k8s' built in certificate manager.  If your distribution doesn't support this (such as Canonical and Rancher), set this to false |
| myvd_config_path | The path to the MyVD configuration file, unless being customized, use `WEB-INF/myvd.conf` |
| dashboard.namespace | The namespace for the dashboard.  For the 1.x dashboard this is `kube-system`, for the 2.x dashboard this is `kubernetes-dashboard` |
| dashboard.cert_name | The name of the secret in the dashboard's namespace that stores the certificate for the dashboard |
| dashboard.label | The label of the dashboard pod, this is used to delete the pod once new certificates are generated |
| dashboard.service_name | The name of the service object for the dashboard |
| k8s_cluster_name | The name of the cluster to use in the `./kube-config`.  Defaults to `kubernetes` |
| image | The name of the image to use |
| enable_impersonation | If `true`, OpenUnison will run in impersonation mode.  Instead of OpenUnison being integrated with Kubernetes via OIDC, OpenUnison will be a reverse proxy and impersonate users.  This is useful with cloud deployments where oidc is not an option |
| monitoring.prometheus_service_account | The prometheus service account to authorize access to the /monitoring endpoint |
| oidc.client_id | The client ID registered with your identity provider |
| oidc.auth_url | Your identity provider's authorization url |
| oidc.token_url | Your identity provider's token url |
| oidc.domain | An email domain to limit access to |
| oidc.user_in_idtoken | Set to `true` if the user's attributes (such as name and groups), is contained in the user's `id_token`.  Set to `false` if a call to the identity provider's user info endpoint is required to load the full profile |
| oidc.userinfo_url | If `oidc.user_in_idtoken` is `false`, the `user_info` endpoint for your identity provider |
| oidc.scopes | The list of scopes to include, may change based on your identity provider |
| oidc.claims.sub | If specified, the claim from the `id_token` to use for the `sub` attribute |
| oidc.claims.email | If specified, the claim from the `id_token` to use for the `mail` attribute |
| oidc.claims.givenName | If specified, the claim from the `id_token` to use for the `givenName` attribute |
| oidc.claims.familyName | If specified, the claim from the `id_token` to use for the `sn` attribute |
| oidc.claims.displayName | If specified, the claim from the `id_token` to use for the `dipslayName` attribute |
| oidc.claims.groups | If specified, the claim from the `id_token` to use for the `groups` attribute |

Additionally, you can add your identity provider's TLS base64 encoded PEM certificate to your values under `trusted_certs` for `pem_b64`.  This will allow OpenUnison to talk to your identity provider using TLS if it doesn't use a commercially signed certificate.  If you don't need a certificate to talk to your identity provider, replace the `trusted_certs` section with `trusted_certs: []`.

Finally, run the helm chart:

`helm install orchestra tremolo/openunison-k8s-login-oidc --namespace openunison -f /path/to/values.yaml`

## Complete SSO Integration with Kubernetes

Run `kubectl describe configmap api-server-config -n openunison` to get the SSO integration artifacts.  The output will give you both the API server flags that need to be configured on your API servers.  The certificate that needs to be trusted is in the `ou-tls-certificate` secret in the `openunison` namespace.

## First Login

To login, open your browser and go to the host you specified for `OU_HOST` in your `input.props`.  For instance if `OU_HOST` is `k8sou.tremolo.lan` then navigate to https://k8sou.tremolo.lan.  You'll be prompted for your Active Directory username and password.  Once authenticated you'll be able login to the portal and generate your `.kube/config` from the Tokens screen.

## Authorizing Access via RBAC

On first login, if you haven't authorized access to any Kubernetes roles you won't be able to do anything.  There are two approaches you can take:

### Group Driven Membership

If you can populate groups in your identity provider for Kubernetes, you can use those groups for authorization via OpenUnison.  OpenUnison will provide all of a user's groups via the `id_token` supplied to Kubernetes.  The `groups` claim is a list of values, in this case the names of the user's groups.  As an example, I created a group in called `k8s-admins`.  To authorize members of this group to be cluster administrators, we create a `ClusterRoleBinding`:

```
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: activedirectory-cluster-admins
subjects:
- kind: Group
  name: k8s-admins
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```

### User Driven Membership

If you are not able to create groups, you can directly add users to role bindings.  Kubernetes requires that you identify openid connect users with the prefix of the url of the identity provider.  So if your `OU_HOST` is `k8sou.tremolo.lan` and your user's login is `mmosley` your username to Kubernetes would be `https://k8sou.tremolo.lan/auth/idp/k8sIdp#mmosley`.  To create a cluster role binding to give cluster-admin access to a specific user:

```
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: activedirectory-cluster-admins
subjects:
- kind: User
  name: https://k8sou.tremolo.lan/auth/idp/k8sIdp#mmosley
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```

*NOTE*: There are multiple reasons this is a bad idea:
1.  Hard to audit - There is no easy way to say "what role bindings is `mmosley` a member of?
2.  Difficult to remove access - Same reason as #1, you need to figure out every role binding a user is a member of to remove
3.  Easy to get wrong - If you mistype a user's login id Kubernetes won't tell you

If you can't use groups from your identity provider, take a look at the OpenUnison Identity Manager for Kubernetes - https://github.com/OpenUnison/openunison-k8s-idm-oidc.  This tool adds on to the login capabilities with the ability to manage access to the cluster and namespaces, along with providing a self service way for users to request new namespaces and manage access.

# Whats next?

Now you can begin mapping OpenUnison's capabilities to your business and compliance needs.  For instance you can add multi-factor authentication with TOTP or U2F, Create privileged workflows for onboarding, scheduled workflows that will deprovision users, etc.

# Using Your Own Certificates

If you want to integrate your own certificates see our wiki entry - https://github.com/TremoloSecurity/OpenUnison/wiki/troubleshooting#how-do-i-change-openunisons-certificates

# Monitoring OpenUnison

This deployment comes with a `/metrics` endpoint for monitoring.  For details on how to integrate it into a Prometheus stack - https://github.com/TremoloSecurity/OpenUnison/wiki/troubleshooting#how-do-i-monitor-openunison-with-prometheus.

# Trouble Shooting Help

Please take a look at https://github.com/TremoloSecurity/OpenUnison/wiki/troubleshooting if you're running into issues.  If there isn't an entry there that takes care of your issue, please open an issue on this repo.

# Customizing Orchestra

To customize Orchestra - https://github.com/TremoloSecurity/OpenUnison/wiki/troubleshooting#customizing-orchestra