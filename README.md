# Flatcar OS issue #278 EKS breaks networking

:warning: This test creates real resources. Ensure you tear down the resources as soon as feasible to reduce AWS costs. :warning:

This is a repository created to reproduce Flatcar OS [issue 278](https://github.com/kinvolk/Flatcar/issues/278) 
for EKS clusters using AWS VPC CNI plugin.
It contains some terraform which will stand up:
- a VPC + bastion node open up to the world on port 22
- one EKS cluster v1.17 
- a node group with 2 instances using Flatcar OS  

The scenario should be driven from `test/flatcar_eks_test.go` which uses [terratest](https://github.com/gruntwork-io/terratest)

Requirements for the machine where the test is run from:
* go 1.15 to run the test
* terraform 0.13.4+ to create the infrastructure
* [aws-iam-authenticator](https://github.com/kubernetes-sigs/aws-iam-authenticator) for programmatic authentication with EKS
* Access/Secret keys to an AWS account where we can stand up EKS

The test will:
* bootstrap the infrastructure using terraform and wait for terraform to finish
* wait until the two required nodes are ready
* wait until coredns pods are ready

This test works with Flatcar Stable `2512.5.0`, but fails with the (current) most recent one - `2605.8.0` 
as the coredns pods never start due to lack of connectivity to the VPC DNS server.

Instructions to execute the test:
* amend `test/flatcar_eks_test.go:25` with the desired version that needs to be tested
* given a public/private SSH keypair that you already have - please add the public ssh key here `test/flatcar_eks_test.go:25`
* execute the tests with `go test -v -count=1 -timeout 1h ./...`

If you would like to retain the infrastructure and use the bastion to debug further, you can consider skipping the `undeploy`
stage like so `SKIP_undeploy=true go test -v -count=1 -timeout 1h ./...` - this will run all stages except the `undeploy` stage which tears down the infrastructure.

If you get stuck - the `terraform` folder in this repo should have the state and all the resources required to run this test.
