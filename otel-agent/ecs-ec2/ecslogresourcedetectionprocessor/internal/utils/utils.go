package utils

import (
	"strconv"
)

// FlattenMap flattens a map[string]interface{} into a map[string]interface{}.
func Flatten(input map[string]interface{}, currentPath string, output map[string]interface{}) {
	for key, value := range input {
		newKey := key
		if currentPath != "" {
			newKey = currentPath + "." + key
		}
		switch child := value.(type) {
		case map[string]interface{}:
			Flatten(child, newKey, output)
		case []interface{}:
			for i, v := range child {
				Flatten(map[string]interface{}{strconv.Itoa(i): v}, newKey, output)
			}
		default:
			output[newKey] = value
		}
	}
}
