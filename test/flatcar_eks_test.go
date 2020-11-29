package test

import (
	"context"
	"fmt"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/labels"
	"os"
	"path/filepath"
	"testing"
	"text/template"
	"time"
)

const (
	Region         = "eu-west-2"
	KubeConfig     = "../terraform/.terraform/kubeconfig"
	TerraformDir   = "../terraform"
	FlatcarChannel = "stable"
	FlatcarRelease = "2512.5.0"
	SshPublicKey   = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCqdydpJuvjZXcBj5DeK3+tvGRJd4YxJSN6FZ+qVlxBNH/m22gxbO+ktdCq+M3/6M4hTS24M+UqHlVfiuIp1IGDh6a7EGMCbojr5KGNq7xUpi1Y+D+y5/t4PPL1FngjkrkQ67smI7gmcLhVuvq8h2IjEtMpXf9A8ACTKsAqKaMz0PU/FQSwUv6+Em5a0Zfn6pkfaAL3VT7hrZMFm7Sw66zfj6UgC5fOLZ2VyHR9TdrBXS0QQbv2Ip29cUkJGQgYCnrrdqdpWPmv0sUNP4bjsO+4nWRP8U80F1ayTyjethxXMsyGgLv5rMePAD8lNIsaBvBb1gvIDDKjGOtiyxRZBpfvNMG5rcyN2y3PgSORxIi4y0Z0yU+A8mJ536+LaGUgIMsf6Hc3WJX2YzcNsW5emcZAcSM2GZu/a05Siqy4zCNu6nxC+Zzhm7IV5vibpJ687zdcCpcf4SbmnRZDqPk+Se6Gjt+XpSzdaY0lFt99QvlGj0/tFDZeIwlivP28m8zAVXGtwgKpWe5MNGxawIlHKPNGJ0Q+tAknJCHKt5Q1x/9bWlz//1rXiBeLmXpYizQfxnlhxilqwdgA5sXqESLIuzqhgQTVyBGTw7YPjP7sZR9pEuoFnm35ROmxie4GCcP9xkUe9cwtAuIPmU1YPEJB8OK05TsDSxIXAe2Lgn5pbJqw3w=="
)

func TestShouldStartEKSCorrectly(t *testing.T) {
	workDir := filepath.Join(TerraformDir, ".terraform", "test_structure")
	defer test_structure.CleanupTestData(t, workDir)

	defer test_structure.RunTestStage(t, "undeploy", func() {
		undeployTerraform(t, workDir)
	})

	test_structure.RunTestStage(t, "deploy", func() {
		deployTerraform(t, workDir)
	})

	test_structure.RunTestStage(t, "verify", func() {
		verifyPodsStarted(t, workDir)
	})
}

func undeployTerraform(t *testing.T, workDir string) {
	terraformOptions := test_structure.LoadTerraformOptions(t, workDir)
	terraform.Destroy(t, terraformOptions)
}

func deployTerraform(t *testing.T, workDir string) {
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: TerraformDir,
		Vars: map[string]interface{}{
			"name":            "flatcar-eks-278",
			"cidr":            "192.168.0.0/19",
			"region":          Region,
			"flatcar_channel": FlatcarChannel,
			"flatcar_version": FlatcarRelease,
			"ssh_public_key":  SshPublicKey,
		},
	})
	test_structure.SaveTerraformOptions(t, workDir, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
}

func verifyPodsStarted(t *testing.T, workDir string) {
	terraformOptions := test_structure.LoadTerraformOptions(t, workDir)
	generateKubeConfig(t, terraformOptions)
	kubeOptions := k8s.NewKubectlOptions("eks", KubeConfig, "kube-system")
	k8sSvc, err := k8s.GetKubernetesClientFromOptionsE(t, kubeOptions)
	if err != nil {
		t.Fatalf("could not get k8s client: %v", err)
	}
	retry.DoWithRetry(t, "two nodes should come up", 30, 10*time.Second, func() (string, error) {
		nodeList, err := k8sSvc.CoreV1().Nodes().List(context.Background(), metav1.ListOptions{})
		if err != nil {
			return "", err
		}
		if len(nodeList.Items) < 2 {
			return "", fmt.Errorf("expecting 2 nodes, got: %v", len(nodeList.Items))
		}

		for _, node := range nodeList.Items {
			if !k8s.IsNodeReady(node) {
				return "", fmt.Errorf("node: %s isn't ready", node.Name)
			}
		}

		logger.Default.Logf(t, "The expected number of nodes have started up")

		return "", nil
	})

	retry.DoWithRetry(t, "coredns pods should be available", 60, 5*time.Second, func() (string, error) {
		labelSelector := map[string]string{
			"k8s-app":                     "kube-dns",
			"eks.amazonaws.com/component": "coredns",
		}
		podList, err := k8sSvc.CoreV1().Pods("kube-system").List(context.Background(), metav1.ListOptions{
			LabelSelector: labels.SelectorFromSet(labelSelector).String(),
		})
		if err != nil {
			return "", err
		}
		for _, pod := range podList.Items {
			for _, status := range pod.Status.ContainerStatuses {
				if !status.Ready {
					return "", fmt.Errorf("pod: %v status isn't ready: %v", pod.Name, status.Name)
				}
			}
		}
		logger.Default.Logf(t, "The expected number of pods have started up")
		return "", nil
	})
}

func generateKubeConfig(t *testing.T, options *terraform.Options) {
	envData := map[string]string{
		"ClusterName":          terraform.Output(t, options, "cluster_name"),
		"ClusterCACertificate": terraform.Output(t, options, "cluster_ca_certificate"),
		"ClusterEndpoint":      terraform.Output(t, options, "cluster_endpoint"),
		"Region":               Region,
	}
	tmpl := template.Must(template.New("").Parse(kubeConfigTemplate))
	outFile, err := os.Create(KubeConfig)
	if err != nil {
		t.Fatalf("could not create kubeconfig: %v", err)
	}
	defer outFile.Close()
	if err := tmpl.Execute(outFile, envData); err != nil {
		t.Fatalf("could not render kubeconfig: %v", err)
	}
}

const kubeConfigTemplate = `
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: {{ .ClusterCACertificate }}
    server: {{ .ClusterEndpoint }}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: eks
  name: eks
current-context: eks
users:
- name: eks
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "{{ .ClusterName }}"
        - --region
        - "{{ .Region }}"
`
