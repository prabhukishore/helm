# Cert Manager

This Chart installs the Kubernetes [Certificate Manager](https://github.com/jetstack/cert-manager). The certificate manage is not used in production but it interfaces with letsencrypt to fetch SSL certificates to use in dev, staging and (eventually) for the blue/green urls.

# Notes

This chart could _basically_ be part of `master-ingress`. However there is one issue with the issuer templates in `master-ingress`: 

```
apiVersion: certmanager.k8s.io/v1alpha1
kind: Issuer
```

There seems to be a bug with helm where it thinks it can't create these resources since the custom resource definition for `Issuer` hasn't been created yet.

I believe this issue is tracked [here](https://github.com/kubernetes/helm/issues/3275).

The workaround seems to be to put the cert-manager in it's own chart.
