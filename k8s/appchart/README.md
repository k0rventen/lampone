# appchart

a simple chart that ease deployment of classic apps on k8s.

##  values

See `example-values.yaml`

## use

In your HelmRelease:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: example
spec:
  chart:
    spec:
      chart: ./k8s/appchart
      version: "x.x.x"
      sourceRef:
        kind: GitRepository
        name: flux-system
        namespace: flux-system
      interval: 10m
  targetNamespace: services
  values:
---


```

## testing

```
helm template -f example-values.yaml . | k apply -f - --dry-run=server
```


## changelog

1.4.0: add `deploymentSpec` key for adding extra config at the deployment level
1.3.0: add annotation so flux avoid reconciliation on ingresses when modified by klipper
1.2.0: added `extras` key that allows settings arbitrary container-level specs
