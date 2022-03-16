package main

import (
	"C"
	"bytes"
	"compress/gzip"
	"fmt"
	"log"
	"net/http"
	"os"
	"regexp"
	"time"
	"unsafe"
)

// Import vendor libraries
import (
	"github.com/araddon/dateparse"
	"github.com/fluent/fluent-bit-go/output"
	jsoniter "github.com/json-iterator/go"
	"github.com/thedevsaddam/gojsonq"
)

//export FLBPluginRegister
func FLBPluginRegister(def unsafe.Pointer) int {
	return output.FLBPluginRegister(def, "coralogix", "Send output to Coralogix")
}

//export FLBPluginInit
func FLBPluginInit(plugin unsafe.Pointer) int {
	// Get output parameters
	endpoint := output.FLBPluginConfigKey(plugin, "Endpoint")
	privateKey := output.FLBPluginConfigKey(plugin, "Private_Key")
	appName := output.FLBPluginConfigKey(plugin, "App_Name")
	subName := output.FLBPluginConfigKey(plugin, "Sub_Name")
	appNameKey := output.FLBPluginConfigKey(plugin, "App_Name_Key")
	subNameKey := output.FLBPluginConfigKey(plugin, "Sub_Name_Key")
	timeKey := output.FLBPluginConfigKey(plugin, "Time_Key")
	logKey := output.FLBPluginConfigKey(plugin, "Log_Key")
	hostKey := output.FLBPluginConfigKey(plugin, "Host_Key")
	debug := output.FLBPluginConfigKey(plugin, "Debug")

	// Debug output
	log.SetPrefix("[CORALOGIX] ")
	log.Println("Initialize sending to Coralogix...")
	log.Printf("Private_Key = ********-****-****-****-******%s\n", privateKey[len(privateKey)-6:])

	// Check Coralogix endpoint
	if endpoint == "" {
		endpoint = "api.coralogix.com"
	}

	// Check Private Key
	privateKeyPattern, _ := regexp.Compile("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
	if privateKey == "" || !privateKeyPattern.MatchString(privateKey) {
		log.Println(" ERROR: invalid Private_Key!")
		return output.FLB_ERROR
	}

	// Check Application name
	if appName == "" {
		appName = "NO_APP_NAME"
	}

	// Check Subsystem name
	if subName == "" {
		subName = "NO_SUB_NAME"
	}

	// Check debug status
	if debug == "On" {
		log.Printf("The Application Name %s and Subsystem Name %s from the Fluent-Bit, has started to send data.", appName, subName)
	}

	// Pass output configuration to context
	output.FLBPluginSetContext(plugin, map[string]string{
		"endpoint":     endpoint,
		"private_key":  privateKey,
		"app_name":     appName,
		"sub_name":     subName,
		"app_name_key": appNameKey,
		"sub_name_key": subNameKey,
		"time_key":     timeKey,
		"log_key":      logKey,
		"host_key":     hostKey,
		"debug":        debug,
	})

	return output.FLB_OK
}

//export FLBPluginFlush
func FLBPluginFlush(data unsafe.Pointer, length C.int, tag *C.char) int {
	return output.FLB_OK
}

//export FLBPluginFlushCtx
func FLBPluginFlushCtx(ctx, data unsafe.Pointer, length C.int, tag *C.char) int {
	// Get plugin instance configuration
	config := output.FLBPluginGetContext(ctx).(map[string]string)

	// Get Coralogix endpoint URL
	endpoint, exists := os.LookupEnv("CORALOGIX_LOG_URL")
	if !exists {
		endpoint = fmt.Sprintf("https://%s/logs/rest/singles", config["endpoint"])
	}

	// Get hostname
	hostname, err := os.Hostname()
	if err != nil {
		hostname = "localhost"
	}

	// Create Fluent-Bit decoder
	decoder := output.NewDecoder(data, int(length))

	// Build records batch
	var batch []interface{}
	for {
		// Extract record
		ret, _, record := output.GetRecord(decoder)
		if ret != 0 {
			break
		}

		// Convert record to JSON
		jsonRecord, err := jsoniter.MarshalToString(toStringMap(record))
		if err != nil {
			log.Printf(" ERROR: %v\n", err)
			continue
		}

		// Parse timestamp
		timestamp, err := dateparse.ParseAny(extractField(jsonRecord, config["time_key"], time.Now().Format(time.RFC3339)))
		if err != nil {
			timestamp = time.Now()
		}

		// Add record to batch
		batch = append(batch, map[string]interface{}{
			"applicationName": extractField(jsonRecord, config["app_name_key"], config["app_name"]),
			"subsystemName":   extractField(jsonRecord, config["sub_name_key"], config["sub_name"]),
			"computerName":    extractField(jsonRecord, config["host_key"], hostname),
			"timestamp":       timestamp.UnixNano() / 1000000,
			"text":            extractField(jsonRecord, config["log_key"], jsonRecord),
		})
	}
	jsonBatch, _ := jsoniter.Marshal(batch)

	// Compress data
	var buffer bytes.Buffer
	zipper, err := gzip.NewWriterLevel(&buffer, 9)
	zipper.Write(jsonBatch)
	zipper.Close()
	if err != nil {
		log.Println(" ERROR: cannot compress the data:", err)
		return output.FLB_RETRY
	}

	// Build request
	request, err := http.NewRequest(http.MethodPost, endpoint, &buffer)
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Content-Encoding", "gzip")
	request.Header.Set("private_key", config["private_key"])
	if err != nil {
		log.Println(" ERROR: cannot build request:", err)
		return output.FLB_RETRY
	}

	// Send records batch
	if config["debug"] == "On" {
		log.Printf(" INFO: Sending %d records...\n", len(batch))
	}
	client := &http.Client{Timeout: 30 * time.Second}
	response, err := client.Do(request)
	if err != nil {
		log.Println(" ERROR: cannot send logs batch:", err)
		return output.FLB_RETRY
	} else if response.StatusCode != 200 {
		log.Println(" ERROR: cannot send logs batch:", response.StatusCode)
		return output.FLB_RETRY
	}

	return output.FLB_OK
}

//export FLBPluginExit
func FLBPluginExit() int {
	return output.FLB_OK
}

//export FLBPluginExitCtx
func FLBPluginExitCtx(ctx unsafe.Pointer) int {
	return output.FLB_OK
}

// toStringMap recursively goes through the slice and converts []byte
// to string so that jsonitor.MarshalToString/json.Marshal don't
// encode []byte to Base64.
func toStringSlice(slice []interface{}) []interface{} {
	var s []interface{}
	for _, v := range slice {
		switch t := v.(type) {
		case []byte:
			s = append(s, string(t))
		case map[interface{}]interface{}:
			s = append(s, toStringMap(t))
		case []interface{}:
			s = append(s, toStringSlice(t))
		default:
			s = append(s, t)
		}
	}
	return s
}

// toStringMap recursively goes through the map and converts []byte
// to string so that jsonitor.MarshalToString/json.Marshal don't
// encode []byte to Base64.
func toStringMap(record map[interface{}]interface{}) map[string]interface{} {
	m := make(map[string]interface{})
	for k, v := range record {
		key, ok := k.(string)
		if !ok {
			continue
		}
		switch t := v.(type) {
		case []byte:
			m[key] = string(t)
		case map[interface{}]interface{}:
			m[key] = toStringMap(t)
		case []interface{}:
			m[key] = toStringSlice(t)
		default:
			m[key] = v
		}
	}

	return m
}

// extractField extracts field value from record
func extractField(jsonRecord string, key string, def string) string {
	if key == "" {
		return def
	}
	jq := gojsonq.New().FromString(jsonRecord)
	result := jq.Find(key)
	if jq.Error() != nil {
		log.Printf(" WARNING: cannot extract field %s from record: %v\n", key, jq.Errors())
		return def
	}
	switch t := result.(type) {
	case string:
		return t
	default:
		subRecord, err := jsoniter.MarshalToString(result)
		if err != nil {
			log.Printf(" WARNING: cannot extract field %s from record: %v\n", key, err)
			return def
		}
		return subRecord
	}
}

func main() {}
