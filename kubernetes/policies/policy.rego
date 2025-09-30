# kubernetes/policies/policy.rego
package main

# This policy denies any Kubernetes resource that is a Deployment
# and does not have a "team" label defined in its metadata.

deny[msg] {
  # Check if the input resource is a Kubernetes Deployment
  input.kind == "Deployment"
  
  # Get the set of labels from the deployment's template metadata
  labels := input.spec.template.metadata.labels
  
  # Check if the "team" key is NOT present in the labels object
  not labels.team
  
  # If all conditions are met, generate this error message
  msg := "Deployments must have a 'team' label"
}
