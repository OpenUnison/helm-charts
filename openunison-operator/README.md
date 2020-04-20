# OpenUnison Operator for Kubernetes

The OpenUnison operator provides an operations automation mechanism for OpenUnison instances running on Kubernetes.  The operator will generate the secrets and objects needed to run OpenUnison:

* Certificate and key generation - no need to ever run the java `keytool` to generate certificates or keys
* Creation of the `Secret`s, `Deployment`s, `Service`s and `Ingress` rules for OpenUnison
* On OpenShift `Route`s, `DeploymentConfig`s, `ImageStream`s and `Build`s
* Import Saml2 Metadata from a URL or direct from XML
* Initialize your database to track audit data
* Deploy and operate ActiveMQ for high availability

## Why an Operator?

Operators help automate common tasks.  For OpenUnison the most common tasks are related to certificate management and service accounts.  For instance when working with a remote SAML2 identity provider like Active Directory Federation Services OpenUnison can check if the trusted certificates have rolled-over and if so redeploy automatically without any administrative intervention.

![OpenUnison Operator and SAML2](https://raw.githubusercontent.com/TremoloSecurity/openunison-k8s-operator/master/imgs/openunison_k8s_operator.png)

In addition to automating common operations tasks, the operator provides you a Kubernetes native way to update OpenUnison's configuration.  Updating your configuration is now a matter of updating objects in Kubernetes instead of having to manually generate keystores or network configurations.

## Deploying the OpenUnison Operator

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

Once deployed, a pod will be running waiting for `OpenUnison` custom resources to be deployed.

## Upgrading the Operator

The OpenUnison operator is updated regularly as known CVEs are patched.  The simplest way to update the operator is to kill the operator's pod and let it pull the latest version.

## The OpenUnison Custom Resource

The OpenUnison custom resource is used to configure:

1. The OpenUnison network configuration - ie ciphers, which keys to use for TLS, etc.
2. The OpenUnison PKCS12 Keystore - All keys and certificates are generated based on Kubernetes secrets.  There's no need to use the Java `keytool`.
3. Parameters `Secret` - OpenUnison lets you integrate parameters into your configuration so that configuration can be stored safely in source control and be used across environments.  This data now comes from Kubernetes objects instead of having to be embedded in one large secret.



Here's an example of a simple `OpenUnison` CR for Kubernetes:

```
apiVersion: openunison.tremolo.io/v1
kind: OpenUnison
metadata:
  name: test-openunison
  namespace: openunison
spec:
  image: tremolosecurity/openunison-simple
  replicas: 1
  enable_activemq: false
  dest_secret: openunison
  source_secret: openunison-secrets-source
  hosts:
    - names:
        - name: test.apps.mydomain.com
          env_var: OU_HOST
      ingress_name: openunison
      secret_name: ou-tls-certificate
  secret_data:
    - unisonKeystorePassword
    - TEST_USER_PASSWORD
    - REG_CRED_PASSWORD
  non_secret_data:
    - name: REG_CRED_USER
      value: rh_user
    - name: TEST_USER_NAME
      value: testuser
    - name: MYVD_CONFIG_PATH
      value: WEB-INF/myvd.conf
    - name: unisonKeystorePath
      value: /etc/openunison/unisonKeyStore.p12
  openunison_network_configuration:
    open_port: 8080
    open_external_port: 80
    secure_port: 8443
    secure_external_port: 443
    secure_key_alias: unison-tls
    force_to_secure: true
    activemq_dir: /tmp/amq
    quartz_dir: /tmp/quartz
    client_auth: none
    allowed_client_names: []
    ciphers:
      - TLS_RSA_WITH_RC4_128_SHA
      - TLS_RSA_WITH_AES_128_CBC_SHA
      - TLS_RSA_WITH_AES_256_CBC_SHA
      - TLS_RSA_WITH_3DES_EDE_CBC_SHA
      - TLS_RSA_WITH_AES_128_CBC_SHA256
      - TLS_RSA_WITH_AES_256_CBC_SHA256
    path_to_deployment: /usr/local/openunison/work
    path_to_env_file: /etc/openunison/ou.env
  key_store:
    static_keys:
      - name: session-unison
        version: 1
    trusted_certificates: 
      - name: trusted-adldaps
      pem_data: |-
                  -----BEGIN CERTIFICATE-----
                  MIIDNDCCAhygAwIBAgIQbRNj6RKqtqVPvW65qZxXXjANBgkqhkiG9w0BAQUFADAi
                  MSAwHgYDVQQDDBdBREZTLkVOVDJLMTIuRE9NQUlOLkNPTTAeFw0xNDAzMjgwMTA1
                  MzNaFw0yNDAzMjUwMTA1MzNaMCIxIDAeBgNVBAMMF0FERlMuRU5UMksxMi5ET01B
                  SU4uQ09NMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2s9JkeNAHOkQ
                  1QYJgjefUwcaogEMcaW/koA+bu9xbr4rHy/2gN/kc8OkoPuwJ/nNlOIO+s+MbnXS
                  L9mUTC4OK7trkEjiKXB+D+VSYy6imXh6zpBtNbeZyx+rdBnaOv3ByZRnnEB8LmhM
                  vHA+4f/t9fx/2vt6wPx//VgIq9yuYYUQRLm1WjyUBFrZeGoSpPm0Kewm+B0bhmMb
                  dyC+3fhaKC+Uk1NPodE2973jLBZJelZxsZY40Ww8zYQwdGYIbXqoTc+1a/x4f1En
                  m4ANqggHtw+Nq8zhss3yTtY+UYKDRBILdLVZQhHJExe0kAeisgMxI/bBwO1HbrFV
                  +zSnk+nvgQIDAQABo2YwZDAzBgNVHSUELDAqBggrBgEFBQcDAQYIKwYBBQUHAwIG
                  CisGAQQBgjcUAgIGCCsGAQUFBwMDMB0GA1UdDgQWBBTyJUfY66zYbm9i0xeYHuFI
                  4MN7uDAOBgNVHQ8BAf8EBAMCBSAwDQYJKoZIhvcNAQEFBQADggEBAM5kz9OKNSuX
                  8w4NOgnfIFdazd0nPlIUbvDVfQoNy9Q0S1SFUVMekIPNiVhfGzya9IwRtGb1VaBQ
                  AQ2ORIzHr8A2r5UNLx3mFjpJmeOxQwlV0X+g8s+253KVFxOpRE6yyagn/BxxptTL
                  a1Z4qeQJLD42ld1qGlRwFtVRmVFZzVXVrpu7NuFd3vlnnO/qKWXU+uMsfXtsl13n
                  ec1kw1Ewq2jnK8WImKTQ7/9WbaIY0gx8mowCJSOsRq0TE7zK/N55drN1wXJVxWe5
                  4N32eCqotXy9j9lzdkNa7awb9q38nWVxP+va5jqNIDlljB6tExy5n3s7t6KK6g5j
                  TZgVqrZ3+ms=
                  -----END CERTIFICATE-----
    key_pairs:
      create_keypair_template:
        - name: ou
          value: k8s
        - name: o
          value: Tremolo Security
        - name: l
          value: Alexandria
        - name: st
          value: Virginia
        - name: c
          value: US
      keys:
        - name: unison-tls
          tls_secret_name: unison-tls-secret
          import_into_ks: keypair
          create_data:
            sign_by_k8s_ca: false
            server_name: test-openunison.openunison.svc.cluster.local
            subject_alternative_names: []
            key_size: 2048
            ca_cert: true
        - name: unison-ca
          tls_secret_name: ou-tls-certificate
          import_into_ks: certificate
          create_data:
            sign_by_k8s_ca: false
            server_name: test.apps.mydomain.com
            subject_alternative_names: []
            key_size: 2048
            ca_cert: false

```




### `hosts`

The `hosts` section tells the operator what `Ingress` objects to create in Kubernetes or `Route`s in OpenShift.  Each host has its host name stored in the environment secret so it can be used in the OpenUnison configuration.  On Kubernetes you can have multiple host names on a single `Ingress` object, on OpenShift each `Route` can have only one host name.

On Kubernetes, you specify the name of the keypair used for the ingress object.

### `secret_data`

This section lists the `data` elements in the `source_secret` that should be imported into the OpenUnison environments secret.

### `non_secret_data`

Use this section for defining parameters that aren't considered secrets.  For instance environment parameters, host names, etc.  Never store passwords in this section.

### `openunison_network_configuration`

The network configuration for OpenUnison, usually can be used as is.

### `key_store`

This section defines what will be in the keystore used by OpenUnison.  Well discuss each section.

#### `static_keys`

OpenUnison makes extensive use of static AES-256 keys.  This section lets you define what keys to create.  Each key listed is added to a `Secret` that stores these keys.  When the `version` is changed, the operator will generate a new key and add it to the keystore.

#### `trusted_certificates`

Each member of this list is added to the keystore as a trusted certificate.  Examples are remote LDAPS services that need to be trusted.

#### `key_pairs`

The OpenUnison operator can either generate self-signed certificates or include TLS key pairs stored as `Secret`s in Kubernetes.

##### `create_keypair_template`

This section defines the components of a generated keypair's subject EXCEPT for the host name.

##### `keys`

Each key listed is either imported from the `Secret` named by `tls_secret_name` if it exist or generates it and stores it in `tls_secret_name`.  When the certificate is generated it is self signed.  The subject is generated based on the `create_data` section.  The generated certificate will use the `server_name` in the subject and will generate a list of subject alternative names **including** the `server_name`.