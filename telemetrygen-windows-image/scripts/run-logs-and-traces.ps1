# Run telemetrygen for both logs and traces. Logs run in background, traces in foreground so the container stays up.
# Env: OTEL_EXPORTER_OTLP_ENDPOINT, OTEL_INSECURE, TELEMETRYGEN_RATE, TELEMETRYGEN_DURATION, TELEMETRYGEN_SERVICE

$ErrorActionPreference = 'Stop'
$endpoint = if ($env:OTEL_EXPORTER_OTLP_ENDPOINT) { $env:OTEL_EXPORTER_OTLP_ENDPOINT } else { 'localhost:4317' }
$insecure = ($env:OTEL_INSECURE -eq 'true' -or $env:OTEL_INSECURE -eq '1')
$rate = if ($env:TELEMETRYGEN_RATE) { $env:TELEMETRYGEN_RATE } else { '1' }
$duration = if ($env:TELEMETRYGEN_DURATION) { $env:TELEMETRYGEN_DURATION } else { '8760h' }
$service = if ($env:TELEMETRYGEN_SERVICE) { $env:TELEMETRYGEN_SERVICE } else { 'telemetrygen-windows' }

$extra = $(if ($insecure) { @('--otlp-insecure') } else { @() })
$logsArgs = @('--otlp-endpoint', $endpoint, '--rate', $rate, '--duration', $duration) + $extra + @('--service', $service)
$tracesArgs = @('--otlp-endpoint', $endpoint, '--rate', $rate, '--duration', $duration) + $extra + @('--service', $service)

# Start logs generator in background (no new window so it stays in same process tree)
$logsProcess = Start-Process -FilePath '.\telemetrygen.exe' -ArgumentList (@('logs') + $logsArgs) -PassThru -NoNewWindow

try {
    # Run traces in foreground to keep container alive
    & .\telemetrygen.exe traces $tracesArgs
} finally {
    if ($logsProcess -and -not $logsProcess.HasExited) {
        Stop-Process -Id $logsProcess.Id -Force -ErrorAction SilentlyContinue
    }
}
