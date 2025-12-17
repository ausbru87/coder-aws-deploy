// Package test contains Terratest tests for Coder deployment Terraform modules
package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestVPCModule validates the VPC module configuration
func TestVPCModule(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/vpc",
		Vars: map[string]interface{}{
			"project_name":         "coder-test",
			"environment":          "test",
			"aws_region":           "us-east-1",
			"vpc_cidr":             "10.0.0.0/16",
			"availability_zones":   []string{"us-east-1a", "us-east-1b", "us-east-1c"},
			"max_workspaces":       100,
			"enable_vpc_endpoints": false,
			"tags":                 map[string]string{"Test": "true"},
		},
		PlanFilePath: "vpc-plan.out",
	})

	// Run terraform plan only (no apply in unit tests)
	terraform.InitAndPlan(t, terraformOptions)
}

// TestEKSModule validates the EKS module configuration
func TestEKSModule(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/eks",
	})

	// Run terraform init and validate (validate doesn't accept -var flags)
	terraform.Init(t, terraformOptions)
	_, err := terraform.ValidateE(t, terraformOptions)
	assert.NoError(t, err, "Terraform validate failed for EKS module")
}

// TestAuroraModule validates the Aurora module configuration
func TestAuroraModule(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/aurora",
	})

	// Run terraform init and validate (validate doesn't accept -var flags)
	terraform.Init(t, terraformOptions)
	_, err := terraform.ValidateE(t, terraformOptions)
	assert.NoError(t, err, "Terraform validate failed for Aurora module")
}

// TestTerraformValidate runs terraform validate on all modules
func TestTerraformValidate(t *testing.T) {
	t.Parallel()

	modules := []string{
		"../modules/vpc",
		"../modules/eks",
		"../modules/aurora",
		"../modules/coder",
	}

	for _, module := range modules {
		module := module // capture range variable
		t.Run(module, func(t *testing.T) {
			t.Parallel()

			terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
				TerraformDir: module,
			})

			// Initialize and validate
			terraform.Init(t, terraformOptions)
			_, err := terraform.ValidateE(t, terraformOptions)
			assert.NoError(t, err, "Terraform validate failed for module: %s", module)
		})
	}
}
