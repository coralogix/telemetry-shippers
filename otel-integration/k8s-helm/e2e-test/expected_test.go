package e2e

var expectedResourceMetricsSchemaURL = map[string]bool{
	"https://opentelemetry.io/schemas/1.6.1": false,
	"https://opentelemetry.io/schemas/1.9.0": false,
}

const expectedScopeVersion = ""

var expectedResourceScopeNames = map[string]bool{
	"github.com/open-telemetry/opentelemetry-collector-contrib/receiver/hostmetricsreceiver/internal/scraper/cpuscraper":        false,
	"github.com/open-telemetry/opentelemetry-collector-contrib/receiver/hostmetricsreceiver/internal/scraper/diskscraper":       false,
	"github.com/open-telemetry/opentelemetry-collector-contrib/receiver/hostmetricsreceiver/internal/scraper/filesystemscraper": false,
	"github.com/open-telemetry/opentelemetry-collector-contrib/receiver/hostmetricsreceiver/internal/scraper/loadscraper":       false,
	"github.com/open-telemetry/opentelemetry-collector-contrib/receiver/hostmetricsreceiver/internal/scraper/memoryscraper":     false,
	"github.com/open-telemetry/opentelemetry-collector-contrib/receiver/hostmetricsreceiver/internal/scraper/networkscraper":    false,
	"github.com/open-telemetry/opentelemetry-collector-contrib/receiver/hostmetricsreceiver/internal/scraper/processscraper":    false,
	"github.com/open-telemetry/opentelemetry-collector-contrib/receiver/kubeletstatsreceiver":                                   false,
	"github.com/open-telemetry/opentelemetry-collector-contrib/receiver/prometheusreceiver":                                     false,
	"github.com/open-telemetry/opentelemetry-collector-contrib/pkg/stanza/fileconsumer":                                         false,
	"github.com/open-telemetry/opentelemetry-collector-contrib/processor/k8sattributesprocessor":                                false,
	"github.com/open-telemetry/opentelemetry-collector-contrib/processor/filterprocessor":                                       false,
	"spanmetricsconnector": false,

	"go.opentelemetry.io/collector/exporter/exporterhelper":          false,
	"go.opentelemetry.io/collector/processor/batchprocessor":         false,
	"go.opentelemetry.io/collector/receiver/receiverhelper":          false,
	"go.opentelemetry.io/collector/processor/memorylimiterprocessor": false,
	"go.opentelemetry.io/collector/processor/processorhelper":        false,
	"go.opentelemetry.io/collector/scraper/scraperhelper":            false,
	"go.opentelemetry.io/collector/service":                          false,
}

var unwantedScopeNames = map[string]struct{}{}

var expectedResourceAttributesKubeletstatreceiver = map[string]string{
	"azure.resourcegroup.name": "",
	"azure.vm.name":            "",
	"azure.vm.scaleset.name":   "",
	"azure.vm.size":            "",
	"cloud.account.id":         "",
	"cloud.platform":           "",
	"cloud.provider":           "azure",
	"cloud.region":             "",
	"cx.otel_integration.name": "coralogix-integration-helm",
	"host.id":                  "",
	"host.name":                "",
	"k8s.cluster.name":         "otel-integration-agent-e2e",
	"k8s.container.name":       "",
	"k8s.daemonset.name":       "",
	"k8s.deployment.name":      "",
	"k8s.job.name":             "",
	"k8s.namespace.name":       "",
	"k8s.node.name":            "otel-integration-agent-e2e-control-plane",
	"k8s.pod.name":             "",
	"k8s.pod.uid":              "",
	"k8s.statefulset.name":     "",
	"os.type":                  "linux",
	"service.version":          "",
}

var expectedResourceAttributesHostmetricsreceiver = map[string]string{
	"azure.resourcegroup.name": "",
	"azure.vm.name":            "",
	"azure.vm.scaleset.name":   "",
	"azure.vm.size":            "",
	"cloud.account.id":         "",
	"cloud.platform":           "azure_vm",
	"cloud.provider":           "azure",
	"cloud.region":             "",
	"cx.otel_integration.name": "coralogix-integration-helm",
	"host.id":                  "",
	"host.name":                "",
	"k8s.cluster.name":         "otel-integration-agent-e2e",
	"k8s.node.name":            "otel-integration-agent-e2e-control-plane",
	"os.type":                  "linux",
	"process.command_line":     "",
	"process.command":          "",
	"process.executable.name":  "",
	"process.executable.path":  "",
	"process.owner":            "",
	"process.parent_pid":       "",
	"process.pid":              "",
	"service.version":          "",
	"service.instance.id":      "",
}

var expectedResourceAttributesK8sattributesprocessor = map[string]string{
	"service.name":             "",
	"net.host.name":            "",
	"server.address":           "",
	"k8s.pod.ip":               "",
	"net.host.port":            "",
	"http.scheme":              "",
	"server.port":              "",
	"url.scheme":               "",
	"cx.agent.type":            "",
	"k8s_node_name":            "",
	"service_instance_id":      "",
	"cx.otel_integration.name": "coralogix-integration-helm",
	"service_version":          "",
	"k8s.cluster.name":         "otel-integration-agent-e2e",
	"k8s.pod.name":             "",
	"k8s.namespace.name":       "",
	"k8s.daemonset.name":       "",
	"k8s.node.name":            "otel-integration-agent-e2e-control-plane",
	"host.name":                "",
	"os.type":                  "linux",
	"host.id":                  "",
	"cloud.provider":           "azure",
	"cloud.platform":           "azure_vm",
	"cloud.region":             "",
	"cloud.account.id":         "",
	"azure.vm.name":            "",
	"azure.vm.size":            "",
	"azure.vm.scaleset.name":   "",
	"azure.resourcegroup.name": "",
	"service.version":          "",
	"service.instance.id":      "",
}

var expectedResourceAttributesService = map[string]string{
	"service.name":             "opentelemetry-collector",
	"net.host.name":            "",
	"server.address":           "",
	"k8s.pod.ip":               "",
	"net.host.port":            "",
	"http.scheme":              "http",
	"server.port":              "",
	"url.scheme":               "",
	"cx.agent.type":            "",
	"k8s.node.name":            "",
	"service.version":          "",
	"k8s.cluster.name":         "otel-integration-agent-e2e",
	"cx.otel_integration.name": "coralogix-integration-helm",
	"k8s.pod.name":             "",
	"k8s.namespace.name":       "",
	"k8s.daemonset.name":       "",
	"host.name":                "",
	"os.type":                  "linux",
	"host.id":                  "",
	"cloud.provider":           "azure",
	"cloud.platform":           "azure_vm",
	"cloud.region":             "",
	"cloud.account.id":         "",
	"azure.vm.name":            "",
	"azure.vm.size":            "",
	"azure.vm.scaleset.name":   "",
	"azure.resourcegroup.name": "",
	"service.instance.id":      "",
}

var expectedResourceAttributesMemorylimiterprocessor = map[string]string{
	"service.name":             "opentelemetry-collector",
	"service.version":          "",
	"net.host.name":            "",
	"server.address":           "",
	"k8s.pod.ip":               "",
	"net.host.port":            "",
	"http.scheme":              "http",
	"server.port":              "",
	"url.scheme":               "",
	"cx.agent.type":            "",
	"k8s_node_name":            "",
	"service_instance_id":      "",
	"cx.otel_integration.name": "coralogix-integration-helm",
	"service_version":          "",
	"k8s.cluster.name":         "otel-integration-agent-e2e",
	"k8s.pod.name":             "",
	"k8s.namespace.name":       "",
	"k8s.daemonset.name":       "",
	"k8s.node.name":            "otel-integration-agent-e2e-control-plane",
	"host.name":                "",
	"os.type":                  "linux",
	"host.id":                  "",
	"cloud.provider":           "azure",
	"cloud.platform":           "azure_vm",
	"cloud.region":             "",
	"cloud.account.id":         "",
	"azure.vm.name":            "",
	"azure.vm.size":            "",
	"azure.vm.scaleset.name":   "",
	"azure.resourcegroup.name": "",
	"service.instance.id":      "",
}

var expectedResourceAttributesSpanmetricsconnector = map[string]string{
	"service.name":             "",
	"service.version":          "",
	"net.host.name":            "",
	"server.address":           "",
	"k8s.pod.ip":               "",
	"net.host.port":            "",
	"http.scheme":              "",
	"server.port":              "",
	"url.scheme":               "",
	"cx.agent.type":            "",
	"k8s_node_name":            "",
	"service_instance_id":      "",
	"cx.otel_integration.name": "coralogix-integration-helm",
	"service_version":          "",
	"k8s.cluster.name":         "otel-integration-agent-e2e",
	"k8s.pod.name":             "",
	"k8s.namespace.name":       "",
	"k8s.daemonset.name":       "",
	"k8s.node.name":            "otel-integration-agent-e2e-control-plane",
	"host.name":                "",
	"os.type":                  "linux",
	"host.id":                  "",
	"cloud.provider":           "azure",
	"cloud.platform":           "azure_vm",
	"cloud.region":             "",
	"cloud.account.id":         "",
	"azure.vm.name":            "",
	"azure.vm.size":            "",
	"azure.vm.scaleset.name":   "",
	"azure.resourcegroup.name": "",
	"service.instance.id":      "",
	"k8s.container.name":       "",
	"k8s.deployment.name":      "",
	"k8s.job.name":             "",
	"k8s.statefulset.name":     "",
}
var expectedResourceAttributesLoadscraper = map[string]string{
	"k8s.cluster.name":         "otel-integration-agent-e2e",
	"cx.otel_integration.name": "coralogix-integration-helm",
	"host.name":                "",
	"os.type":                  "linux",
	"host.id":                  "",
	"k8s.node.name":            "otel-integration-agent-e2e-control-plane",
	"cloud.provider":           "azure",
	"cloud.platform":           "azure_vm",
	"cloud.region":             "",
	"cloud.account.id":         "",
	"azure.vm.name":            "",
	"azure.vm.size":            "",
	"azure.vm.scaleset.name":   "",
	"azure.resourcegroup.name": "",
	"service.version":          "",
	"service.instance.id":      "",
}

var expectedResourceAttributesPrometheusreceiver = map[string]string{
	"azure.resourcegroup.name": "",
	"azure.vm.name":            "",
	"azure.vm.scaleset.name":   "",
	"azure.vm.size":            "",
	"cloud.account.id":         "",
	"cloud.platform":           "",
	"cloud.provider":           "azure",
	"cloud.region":             "",
	"cx.otel_integration.name": "coralogix-integration-helm",
	"host.id":                  "",
	"host.name":                "",
	"http.scheme":              "http",
	"k8s_node_name":            "",
	"k8s.cluster.name":         "otel-integration-agent-e2e",
	"k8s.daemonset.name":       "",
	"k8s.deployment.name":      "",
	"k8s.namespace.name":       "",
	"k8s.node.name":            "otel-integration-agent-e2e-control-plane",
	"k8s.pod.ip":               "",
	"k8s.pod.name":             "",
	"net.host.name":            "",
	"net.host.port":            "",
	"os.type":                  "linux",
	"server.address":           "",
	"server.port":              "",
	"service.version":          "",
	"service_instance_id":      "",
	"service.name":             "opentelemetry-collector",
	"url.scheme":               "",
	"cx.agent.type":            "",
	"service.instance.id":      "",
}

var expectedResourceAttributesProcessscraper = map[string]string{
	"process.pid":              "",
	"process.parent_pid":       "",
	"process.executable.name":  "",
	"process.executable.path":  "",
	"process.command":          "",
	"process.command_line":     "",
	"k8s.cluster.name":         "otel-integration-agent-e2e",
	"cx.otel_integration.name": "coralogix-integration-helm",
	"host.name":                "",
	"os.type":                  "linux",
	"host.id":                  "",
	"k8s.node.name":            "otel-integration-agent-e2e-control-plane",
	"cloud.provider":           "azure",
	"cloud.platform":           "azure_vm",
	"cloud.region":             "",
	"cloud.account.id":         "",
	"azure.vm.name":            "",
	"azure.vm.size":            "",
	"azure.vm.scaleset.name":   "",
	"azure.resourcegroup.name": "",
	"service.version":          "",
	"service.instance.id":      "",
}

var expectedResourceAttributesProcessorhelper = map[string]string{
	"service.name":             "opentelemetry-collector",
	"net.host.name":            "",
	"server.address":           "",
	"k8s.pod.ip":               "",
	"net.host.port":            "",
	"http.scheme":              "http",
	"server.port":              "",
	"url.scheme":               "",
	"cx.agent.type":            "",
	"k8s.node.name":            "otel-integration-agent-e2e-control-plane",
	"service.version":          "",
	"k8s.cluster.name":         "otel-integration-agent-e2e",
	"cx.otel_integration.name": "coralogix-integration-helm",
	"k8s.pod.name":             "",
	"k8s.namespace.name":       "",
	"k8s.daemonset.name":       "",
	"host.name":                "",
	"os.type":                  "linux",
	"host.id":                  "",
	"cloud.provider":           "azure",
	"cloud.platform":           "azure_vm",
	"cloud.region":             "",
	"cloud.account.id":         "",
	"azure.vm.name":            "",
	"azure.vm.size":            "",
	"azure.vm.scaleset.name":   "",
	"azure.resourcegroup.name": "",
	"service.instance.id":      "",
}

var expectedMetrics map[string]bool = map[string]bool{
	"container.cpu.time":                              false,
	"container.cpu.utilization":                       false,
	"container.filesystem.available":                  false,
	"container.filesystem.capacity":                   false,
	"container.filesystem.usage":                      false,
	"container.memory.available":                      false,
	"container.memory.major_page_faults":              false,
	"container.memory.page_faults":                    false,
	"container.memory.rss":                            false,
	"container.memory.usage":                          false,
	"container.memory.working_set":                    false,
	"k8s.node.cpu.time":                               false,
	"k8s.node.cpu.utilization":                        false,
	"k8s.node.filesystem.available":                   false,
	"k8s.node.filesystem.capacity":                    false,
	"k8s.node.filesystem.usage":                       false,
	"k8s.node.memory.available":                       false,
	"k8s.node.memory.major_page_faults":               false,
	"k8s.node.memory.page_faults":                     false,
	"k8s.node.memory.rss":                             false,
	"k8s.node.memory.usage":                           false,
	"k8s.node.memory.working_set":                     false,
	"k8s.node.network.errors":                         false,
	"k8s.node.network.io":                             false,
	"k8s.pod.cpu.time":                                false,
	"k8s.pod.cpu.utilization":                         false,
	"k8s.pod.filesystem.available":                    false,
	"k8s.pod.filesystem.capacity":                     false,
	"k8s.pod.filesystem.usage":                        false,
	"k8s.pod.memory.available":                        false,
	"k8s.pod.memory.major_page_faults":                false,
	"k8s.pod.memory.page_faults":                      false,
	"k8s.pod.memory.rss":                              false,
	"k8s.pod.memory.usage":                            false,
	"k8s.pod.memory.working_set":                      false,
	"k8s.pod.network.errors":                          false,
	"k8s.pod.network.io":                              false,
	"otelcol_exporter_queue_capacity":                 false,
	"otelcol_exporter_queue_size":                     false,
	"otelcol_exporter_send_failed_log_records":        false,
	"otelcol_exporter_send_failed_metric_points":      false,
	"otelcol_exporter_send_failed_spans":              false,
	"otelcol_exporter_sent_log_records":               false,
	"otelcol_exporter_sent_metric_points":             false,
	"otelcol_exporter_sent_spans":                     false,
	"otelcol_process_cpu_seconds":                     false,
	"otelcol_process_memory_rss_bytes":                false,
	"otelcol_process_runtime_heap_alloc_bytes":        false,
	"otelcol_process_runtime_total_alloc_bytes":       false,
	"otelcol_process_runtime_total_sys_memory_bytes":  false,
	"otelcol_process_uptime_seconds":                  false,
	"otelcol_processor_accepted_metric_points":        false,
	"otelcol_processor_accepted_log_records":          false,
	"otelcol_processor_accepted_spans":                false,
	"otelcol_processor_batch_batch_send_size":         false,
	"otelcol_processor_batch_batch_size_trigger_send": false,
	"otelcol_processor_batch_metadata_cardinality":    false,
	"otelcol_processor_batch_timeout_trigger_send":    false,
	"otelcol_processor_filter_spans.filtered_ratio":   false,
	"otelcol_processor_incoming_items":                false,
	"otelcol_processor_outgoing_items":                false,
	"otelcol_receiver_accepted_log_records":           false,
	"otelcol_receiver_accepted_metric_points":         false,
	"otelcol_receiver_accepted_spans":                 false,
	"otelcol_receiver_refused_log_records":            false,
	"otelcol_receiver_refused_metric_points":          false,
	"otelcol_receiver_refused_spans":                  false,
	"otelcol_scraper_errored_metric_points":           false,
	"otelcol_scraper_scraped_metric_points":           false,
	"process.cpu.time":                                false,
	"process.cpu.utilization":                         false,
	"process.disk.io":                                 false,
	"process.memory.usage":                            false,
	"process.memory.utilization":                      false,
	"process.memory.virtual":                          false,
	"process.threads":                                 false,
	"scrape_duration_seconds":                         false,
	"scrape_samples_post_metric_relabeling":           false,
	"scrape_samples_scraped":                          false,
	"scrape_series_added":                             false,
	"system.cpu.load_average.15m":                     false,
	"system.cpu.load_average.1m":                      false,
	"system.cpu.load_average.5m":                      false,
	"system.cpu.time":                                 false,
	"system.cpu.utilization":                          false,
	"system.disk.io_time":                             false,
	"system.disk.io":                                  false,
	"system.disk.merged":                              false,
	"system.disk.operation_time":                      false,
	"system.disk.operations":                          false,
	"system.disk.pending_operations":                  false,
	"system.disk.weighted_io_time":                    false,
	"system.filesystem.inodes.usage":                  false,
	"system.filesystem.usage":                         false,
	"system.memory.usage":                             false,
	"system.memory.utilization":                       false,
	"system.network.connections":                      false,
	"system.network.dropped":                          false,
	"system.network.errors":                           false,
	"system.network.io":                               false,
	"system.network.packets":                          false,
	"up":                                              false,
	"promhttp_metric_handler_errors":                  false,
	"otelcol_fileconsumer_open_files_ratio":           false,
	"otelcol_fileconsumer_reading_files_ratio":        false,
	"otelcol_otelsvc_k8s_ip_lookup_miss_ratio":        false,
	"otelcol_otelsvc_k8s_pod_added_ratio":             false,
	"otelcol_otelsvc_k8s_pod_table_size_ratio":        false,
	"otelcol_otelsvc_k8s_pod_updated_ratio":           false,
	"otelcol_otelsvc_k8s_pod_deleted_ratio":           false,
	"calls":                                           false,
	"duration":                                        false,
}

var expectedTracesSchemaURL = map[string]bool{
	"https://opentelemetry.io/schemas/1.4.0":  false,
	"https://opentelemetry.io/schemas/1.25.0": false,
}

var expectedLogsSchemaURL = map[string]bool{
	"https://opentelemetry.io/schemas/1.6.1": false,
}

var expectedHostEntityAttributes = map[string]expectedValue{
	// Required attributes
	"cx.otel_integration.name": newExpectedValue(attributeMatchTypeEqual, "coralogix-integration-helm"),
	"host.cpu.cache.l2.size":   newExpectedValue(attributeMatchTypeExist, ""),
	"host.cpu.family":          newExpectedValue(attributeMatchTypeExist, ""),
	"host.cpu.model.id":        newExpectedValue(attributeMatchTypeExist, ""),
	"host.cpu.model.name":      newExpectedValue(attributeMatchTypeExist, ""),
	"host.cpu.stepping":        newExpectedValue(attributeMatchTypeExist, ""),
	"host.cpu.vendor.id":       newExpectedValue(attributeMatchTypeExist, ""),
	"host.id":                  newExpectedValue(attributeMatchTypeRegex, "^[a-f0-9-]{32,36}$"),
	"host.ip":                  newExpectedValue(attributeMatchTypeExist, ""),
	"host.mac":                 newExpectedValue(attributeMatchTypeExist, ""),
	"host.name":                newExpectedValue(attributeMatchTypeExist, ""),
	"k8s.cluster.name":         newExpectedValue(attributeMatchTypeEqual, "otel-integration-agent-e2e"),
	"k8s.node.name":            newExpectedValue(attributeMatchTypeOptional, ""),
	"os.description":           newExpectedValue(attributeMatchTypeRegex, "^Linux .* (aarch64|x86_64)$"),
	"os.type":                  newExpectedValue(attributeMatchTypeEqual, "linux"),
	"otel.entity.event.type":   newExpectedValue(attributeMatchTypeEqual, "entity_state"),
	"otel.entity.id":           newExpectedValue(attributeMatchTypeExist, ""),
	"otel.entity.interval":     newExpectedValue(attributeMatchTypeEqual, "300000"),
	"otel.entity.type":         newExpectedValue(attributeMatchTypeEqual, "host"),

	// Optional attributes (may be present in cloud environments)
	"azure.resourcegroup.name": newExpectedValue(attributeMatchTypeOptional, ""),
	"azure.vm.name":            newExpectedValue(attributeMatchTypeOptional, ""),
	"azure.vm.scaleset.name":   newExpectedValue(attributeMatchTypeOptional, ""),
	"azure.vm.size":            newExpectedValue(attributeMatchTypeOptional, ""),
	"cloud.account.id":         newExpectedValue(attributeMatchTypeOptional, ""),
	"cloud.platform":           newExpectedValue(attributeMatchTypeOptional, ""),
	"cloud.provider":           newExpectedValue(attributeMatchTypeOptional, ""),
	"cloud.region":             newExpectedValue(attributeMatchTypeOptional, ""),
}

func expectedTraces(testID string, testNs string) map[string]struct {
	name    string
	service string
	attrs   map[string]expectedValue
} {
	return map[string]struct {
		name    string
		service string
		attrs   map[string]expectedValue
	}{
		"test-traces-job": {
			name:    "traces-job",
			service: "test-traces-job",
			attrs: map[string]expectedValue{
				"cx.otel_integration.name": newExpectedValue(attributeMatchTypeEqual, "coralogix-integration-helm"),
				"k8s.cluster.name":         newExpectedValue(attributeMatchTypeEqual, "otel-integration-agent-e2e"),
				"k8s.job.name":             newExpectedValue(attributeMatchTypeEqual, "telemetrygen-"+testID+"-traces-job"),
				"k8s.namespace.name":       newExpectedValue(attributeMatchTypeEqual, testNs),
				"k8s.node.name":            newExpectedValue(attributeMatchTypeExist, ""),
				"k8s.pod.name":             newExpectedValue(attributeMatchTypeRegex, "telemetrygen-"+testID+"-traces-job-[a-z0-9]*"),
			},
		},
		"test-traces-statefulset": {
			name:    "traces-statefulset",
			service: "test-traces-statefulset",
			attrs: map[string]expectedValue{
				"cx.otel_integration.name": newExpectedValue(attributeMatchTypeEqual, "coralogix-integration-helm"),
				"k8s.cluster.name":         newExpectedValue(attributeMatchTypeEqual, "otel-integration-agent-e2e"),
				"k8s.namespace.name":       newExpectedValue(attributeMatchTypeEqual, testNs),
				"k8s.node.name":            newExpectedValue(attributeMatchTypeExist, ""),
				"k8s.pod.name":             newExpectedValue(attributeMatchTypeEqual, "telemetrygen-"+testID+"-traces-statefulset-0"),
				"k8s.statefulset.name":     newExpectedValue(attributeMatchTypeEqual, "telemetrygen-"+testID+"-traces-statefulset"),
			},
		},
		"test-traces-deployment": {
			name:    "traces-deployment",
			service: "test-traces-deployment",
			attrs: map[string]expectedValue{
				"cx.otel_integration.name": newExpectedValue(attributeMatchTypeEqual, "coralogix-integration-helm"),
				"k8s.cluster.name":         newExpectedValue(attributeMatchTypeEqual, "otel-integration-agent-e2e"),
				"k8s.deployment.name":      newExpectedValue(attributeMatchTypeEqual, "telemetrygen-"+testID+"-traces-deployment"),
				"k8s.namespace.name":       newExpectedValue(attributeMatchTypeEqual, testNs),
				"k8s.node.name":            newExpectedValue(attributeMatchTypeExist, ""),
				"k8s.pod.name":             newExpectedValue(attributeMatchTypeRegex, "telemetrygen-"+testID+"-traces-deployment-[a-z0-9]*-[a-z0-9]*"),
			},
		},
		"test-traces-daemonset": {
			name:    "traces-daemonset",
			service: "test-traces-daemonset",
			attrs: map[string]expectedValue{
				"cx.otel_integration.name": newExpectedValue(attributeMatchTypeEqual, "coralogix-integration-helm"),
				"k8s.cluster.name":         newExpectedValue(attributeMatchTypeEqual, "otel-integration-agent-e2e"),
				"k8s.daemonset.name":       newExpectedValue(attributeMatchTypeEqual, "telemetrygen-"+testID+"-traces-daemonset"),
				"k8s.namespace.name":       newExpectedValue(attributeMatchTypeEqual, testNs),
				"k8s.node.name":            newExpectedValue(attributeMatchTypeExist, ""),
				"k8s.pod.name":             newExpectedValue(attributeMatchTypeRegex, "telemetrygen-"+testID+"-traces-daemonset-[a-z0-9]*"),
			},
		},
	}
}
