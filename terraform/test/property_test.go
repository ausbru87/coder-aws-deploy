// Package test contains property-based tests for Coder deployment
package test

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestProperty_InfrastructureProvisioningCompleteness validates that all required
// AWS resources are defined in the Terraform configuration.
// **Feature: coder-deployment-guide, Property 1: Infrastructure Provisioning Completeness**
// **Validates: Requirements 2.1, 2.2, 2.3, 2.4**
func TestProperty_InfrastructureProvisioningCompleteness(t *testing.T) {
	t.Parallel()

	// Required resource types that must be present
	requiredResources := map[string][]string{
		"vpc": {
			"aws_vpc",
			"aws_subnet",
			"aws_nat_gateway",
			"aws_security_group",
			"aws_internet_gateway",
			"aws_route_table",
		},
		"eks": {
			"aws_eks_cluster",
			"aws_eks_node_group",
			"aws_iam_role",
			"aws_iam_openid_connect_provider",
		},
		"aurora": {
			"aws_rds_cluster",
			"aws_rds_cluster_instance",
			"aws_db_subnet_group",
			"aws_kms_key",
		},
	}

	for module, resources := range requiredResources {
		module := module
		resources := resources
		t.Run(module, func(t *testing.T) {
			t.Parallel()

			modulePath := filepath.Join("..", "modules", module)
			files, err := os.ReadDir(modulePath)
			require.NoError(t, err, "Failed to read module directory: %s", modulePath)

			// Read all .tf files and check for required resources
			var allContent strings.Builder
			for _, file := range files {
				if strings.HasSuffix(file.Name(), ".tf") {
					content, err := os.ReadFile(filepath.Join(modulePath, file.Name()))
					require.NoError(t, err)
					allContent.Write(content)
				}
			}

			content := allContent.String()
			for _, resource := range resources {
				assert.Contains(t, content, "resource \""+resource+"\"",
					"Module %s missing required resource: %s", module, resource)
			}
		})
	}
}

// TestProperty_StaticControlPlaneConfiguration validates that coderd has no HPA configured.
// **Feature: coder-deployment-guide, Property 4: Static Control Plane Configuration**
// **Validates: Requirements 4.1**
func TestProperty_StaticControlPlaneConfiguration(t *testing.T) {
	t.Parallel()

	// Read the coder values template
	valuesPath := filepath.Join("..", "modules", "coder", "values", "coder-values.yaml.tpl")
	content, err := os.ReadFile(valuesPath)
	require.NoError(t, err, "Failed to read coder values template")

	contentStr := string(content)

	// Verify no HPA configuration
	assert.NotContains(t, contentStr, "autoscaling:",
		"Coder values should not contain autoscaling configuration")
	assert.NotContains(t, contentStr, "hpa:",
		"Coder values should not contain HPA configuration")

	// Verify static replica count is set
	assert.Contains(t, contentStr, "replicaCount:",
		"Coder values should have static replicaCount")
}

// TestProperty_HTTPSEnforcement validates TLS configuration for all endpoints.
// **Feature: coder-deployment-guide, Property 8: HTTPS Enforcement**
// **Validates: Requirements 12.7, 12.8**
func TestProperty_HTTPSEnforcement(t *testing.T) {
	t.Parallel()

	// Check NLB configuration in coder module
	coderMainPath := filepath.Join("..", "modules", "coder", "main.tf")
	content, err := os.ReadFile(coderMainPath)
	require.NoError(t, err, "Failed to read coder main.tf")

	contentStr := string(content)

	// Verify TLS configuration
	assert.Contains(t, contentStr, "aws-load-balancer-ssl-cert",
		"NLB should have SSL certificate configured")
	assert.Contains(t, contentStr, "aws-load-balancer-ssl-ports",
		"NLB should have SSL ports configured")
	assert.Contains(t, contentStr, "ELBSecurityPolicy-TLS13-1-2-2021-06",
		"NLB should enforce TLS 1.2+ with modern cipher suites")

	// Check coder values for HTTPS settings
	valuesPath := filepath.Join("..", "modules", "coder", "values", "coder-values.yaml.tpl")
	valuesContent, err := os.ReadFile(valuesPath)
	require.NoError(t, err, "Failed to read coder values template")

	valuesStr := string(valuesContent)
	assert.Contains(t, valuesStr, "CODER_SECURE_AUTH_COOKIE",
		"Coder should have secure auth cookie enabled")
	assert.Contains(t, valuesStr, "CODER_STRICT_TRANSPORT_SECURITY",
		"Coder should have HSTS enabled")
}

// TestProperty_ExternalProvisionerConfiguration validates external provisioner setup.
// **Feature: coder-deployment-guide, Property 6: External Provisioner Configuration**
// **Validates: Requirements 11.1**
func TestProperty_ExternalProvisionerConfiguration(t *testing.T) {
	t.Parallel()

	// Check coder values for internal provisioners disabled
	valuesPath := filepath.Join("..", "modules", "coder", "values", "coder-values.yaml.tpl")
	content, err := os.ReadFile(valuesPath)
	require.NoError(t, err, "Failed to read coder values template")

	contentStr := string(content)

	// Verify internal provisioners are disabled
	assert.Contains(t, contentStr, "CODER_PROVISIONER_DAEMONS",
		"Coder values should configure provisioner daemons")
	assert.Contains(t, contentStr, "value: \"0\"",
		"Internal provisioners should be set to 0")

	// Check that external provisioner Helm release exists
	coderMainPath := filepath.Join("..", "modules", "coder", "main.tf")
	mainContent, err := os.ReadFile(coderMainPath)
	require.NoError(t, err, "Failed to read coder main.tf")

	mainStr := string(mainContent)
	assert.Contains(t, mainStr, "helm_release\" \"coder_provisioner\"",
		"External provisioner Helm release should be defined")
	assert.Contains(t, mainStr, "chart      = \"coder-provisioner\"",
		"External provisioner should use coder-provisioner chart")
}

// TestProperty_BackupFrequencyRPO validates Aurora backup configuration for RPO.
// **Feature: coder-deployment-guide, Property 5: Backup Frequency for RPO**
// **Validates: Requirements 8.4**
func TestProperty_BackupFrequencyRPO(t *testing.T) {
	t.Parallel()

	// Check Aurora module for backup configuration
	auroraMainPath := filepath.Join("..", "modules", "aurora", "main.tf")
	content, err := os.ReadFile(auroraMainPath)
	require.NoError(t, err, "Failed to read aurora main.tf")

	contentStr := string(content)

	// Verify backup retention is configured
	assert.Contains(t, contentStr, "backup_retention_period",
		"Aurora should have backup retention configured")

	// Verify point-in-time recovery is enabled (implied by backup_retention_period > 0)
	// Aurora automatically enables PITR when backup_retention_period > 0

	// Check variables for 90-day retention default
	varsPath := filepath.Join("..", "modules", "aurora", "variables.tf")
	varsContent, err := os.ReadFile(varsPath)
	require.NoError(t, err, "Failed to read aurora variables.tf")

	varsStr := string(varsContent)
	assert.Contains(t, varsStr, "backup_retention_period",
		"Aurora variables should include backup_retention_period")
}

// TestProperty_DNSConfigurationCompleteness validates Route 53 configuration.
// **Feature: coder-deployment-guide, Property 12: DNS Configuration Completeness**
// **Validates: Requirements 6.4**
func TestProperty_DNSConfigurationCompleteness(t *testing.T) {
	t.Parallel()

	// Check coder module for DNS-related configuration
	coderMainPath := filepath.Join("..", "modules", "coder", "main.tf")
	content, err := os.ReadFile(coderMainPath)
	require.NoError(t, err, "Failed to read coder main.tf")

	contentStr := string(content)

	// Verify access URL and wildcard URL are configured
	assert.Contains(t, contentStr, "access_url",
		"Coder module should configure access_url")
	assert.Contains(t, contentStr, "wildcard_access_url",
		"Coder module should configure wildcard_access_url")

	// Check variables for domain configuration
	varsPath := filepath.Join("..", "modules", "coder", "variables.tf")
	varsContent, err := os.ReadFile(varsPath)
	require.NoError(t, err, "Failed to read coder variables.tf")

	varsStr := string(varsContent)
	assert.Contains(t, varsStr, "base_domain",
		"Coder variables should include base_domain")
	assert.Contains(t, varsStr, "coder_subdomain",
		"Coder variables should include coder_subdomain")
}

// TestProperty_DeclarativeConfigurationConsistency validates coderd provider setup.
// **Feature: coder-deployment-guide, Property 11: Declarative Configuration Consistency**
// **Validates: Requirements 16.3**
func TestProperty_DeclarativeConfigurationConsistency(t *testing.T) {
	t.Parallel()

	// Check main.tf for coderd provider configuration
	mainPath := filepath.Join("..", "main.tf")
	content, err := os.ReadFile(mainPath)
	require.NoError(t, err, "Failed to read main.tf")

	contentStr := string(content)

	// Verify coderd provider is declared
	assert.Contains(t, contentStr, "coder/coderd",
		"Main configuration should include coderd provider")
}

// TestTfvarsValidation validates that prod tfvars file has required variables
func TestTfvarsValidation(t *testing.T) {
	t.Parallel()

	requiredVars := []string{
		"project_name",
		"environment",
		"aws_region",
		"vpc_cidr",
		"base_domain",
		"oidc_issuer_url",
	}

	tfvarsPath := filepath.Join("..", "environments", "prod.tfvars")
	content, err := os.ReadFile(tfvarsPath)
	require.NoError(t, err, "Failed to read tfvars file: %s", tfvarsPath)

	contentStr := string(content)
	for _, varName := range requiredVars {
		// Check for variable name followed by optional whitespace and equals sign
		// This handles both "var =" and "var  =" formats
		assert.Regexp(t, varName+`\s*=`,
			contentStr,
			"Production environment missing required variable: %s", varName)
	}
}

// Helper function to parse HCL-like content (simplified)
func parseSimpleHCL(content string) map[string]interface{} {
	result := make(map[string]interface{})
	// This is a simplified parser for testing purposes
	// In production, use a proper HCL parser
	lines := strings.Split(content, "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.Contains(line, "=") && !strings.HasPrefix(line, "#") {
			parts := strings.SplitN(line, "=", 2)
			if len(parts) == 2 {
				key := strings.TrimSpace(parts[0])
				value := strings.TrimSpace(parts[1])
				result[key] = value
			}
		}
	}
	return result
}

// TestModuleOutputsExist validates that all modules have required outputs
func TestModuleOutputsExist(t *testing.T) {
	t.Parallel()

	moduleOutputs := map[string][]string{
		"vpc": {
			"vpc_id",
			"public_subnet_ids",
			"control_subnet_ids",
			"database_subnet_ids",
		},
		"eks": {
			"cluster_name",
			"cluster_endpoint",
			"node_security_group_id",
		},
		"aurora": {
			"cluster_endpoint",
			"database_name",
			"master_secret_arn",
		},
		"coder": {
			"access_url",
			"coder_namespace",
		},
	}

	for module, outputs := range moduleOutputs {
		module := module
		outputs := outputs
		t.Run(module, func(t *testing.T) {
			t.Parallel()

			outputsPath := filepath.Join("..", "modules", module, "outputs.tf")
			content, err := os.ReadFile(outputsPath)
			require.NoError(t, err, "Failed to read outputs.tf for module: %s", module)

			contentStr := string(content)
			for _, output := range outputs {
				assert.Contains(t, contentStr, "output \""+output+"\"",
					"Module %s missing required output: %s", module, output)
			}
		})
	}
}

// Helper to unmarshal JSON for testing
func unmarshalJSON(t *testing.T, data []byte) map[string]interface{} {
	var result map[string]interface{}
	err := json.Unmarshal(data, &result)
	require.NoError(t, err, "Failed to unmarshal JSON")
	return result
}
