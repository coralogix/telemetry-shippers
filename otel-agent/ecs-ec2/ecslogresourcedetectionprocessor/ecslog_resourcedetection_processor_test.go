package ecslogresourcedetectionprocessor

import "testing"

func TestFormatLabels(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{
			input:    "Labels.com.amazonaws.ecs.cluster",
			expected: "ecs.cluster",
		},
		{
			input:    "ContainerARN",
			expected: "container.arn",
		},
		{
			input:    "Networks.0.IPv4Addresses.0",
			expected: "networks.0.ipv4.addresses.0",
		},
		{
			input:    "Image",
			expected: "image",
		},
	}

	for _, test := range tests {
		result := formatLabel(test.input)
		if result != test.expected {
			t.Errorf("Input: %s\nExpected: %s\nGot: %s\n", test.input, test.expected, result)
		}
	}
}
