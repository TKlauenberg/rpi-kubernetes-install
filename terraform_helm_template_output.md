# Possible Way to debug helm charts

Sometimes it is valuable to see which templates a helm chart renders.
In order to see that template which is created by terraform an output value can be used.

This helm configuration will be the example:

```terraform
resource "helm_release" "metallb_networking" {
  name       = "metallb"
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"

  cleanup_on_fail = true
  force_update    = true
  namespace       = "metallb-system"
}
```

If the data is used instead of the resource, an output can be created which would be the same as `helm template` output.

```terraform
data "helm_template" "metallb_networking" {
  name       = "metallb"
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"

  cleanup_on_fail = true
  force_update    = true
  namespace       = "metallb-system"
}

output "helm_yaml" {
  value = data.helm_template.metallb_networking.manifest
}
```
After a `terraform plan` or a `terraform refresh` the statefile holds the output value of the template.
If sensetive data is part of the helm demplate the attribute 'sensitive' must be  set to `true`.
The output value can be seen with the command `terraform output helm_yaml`.