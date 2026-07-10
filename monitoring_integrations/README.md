# Monitoring Integrations

## 1. Grafana

If you have Grafana available, you can access visualizations using the YugabyteDB Grafana dashboard, which is included with your YBA installation. 

Ensure the following pre-requisite is met:
- Network connectivity from your Grafana instance to YBA instance's embedded Promtheus on port 9090

### 1.1 Add YBA's Prometheus as a Grafana data source

1. Navigate to Grafana UI and login as a user with the organization administrator role 
1. Navigate to Connections > Data sources in the left-side menu
1. Click "Add a new data source" > "Prometheus"
1. Under Prometheus server URL, enter `https://<yba_ip>:9090`
  - Optional: Enable `Skip TLS certificate validation` if needed
1. Leave the rest of the fields at their default values
1. Click "Save & test"

Once you have successfully added the data source, proceed to import the Grafana dashboard.

### 1.2 Download Grafana dashboard JSON

1. Navigate to YBA UI > Your Universe > Metrics
1. In the top right corner, click on the gear icon > download Grafana JSON


### 1.3 Import Grafana dashboard JSON

1. Navigate to Grafana UI
1. In the op right corner, click on "+" > "Import dashboard"
1. Upload the dashboard JSON file and click "Import"
1. You should be redirected to the dashboard
1. Click on the "datasource" dropdown and select the datasource you created in 15.1
1. Click on the "YugabyteDB Cluster" dropdown and select your universe

---

## 2. Elastic

Shipping metrics from YBA's embedded Prometheus to Elasticsearch can be done using Metricbeat.

Ensure the following pre-requisite is met:
- Network connectivity from your YBA instance to your Elasticsearch instance

### 2.1 Install Metricbeat on YBA VM

- Refer to the [official installation guide](https://www.elastic.co/docs/reference/beats/metricbeat/metricbeat-installation-configuration)

### 2.2 Configure Metricbeat to send metrics to Elasticsearch

We'll use the [Prometheus module](https://www.elastic.co/docs/reference/beats/metricbeat/metricbeat-module-prometheus) to send metrics to Elasticsearch.

Firstly, test the integration with a basic configuration using the [Promtheus query metricset](https://www.elastic.co/docs/reference/beats/metricbeat/metricbeat-metricset-prometheus-query). 

Add the following [configuration](https://www.elastic.co/docs/reference/beats/metricbeat/configuration-metricbeat) to your Metricbeat:
```yaml
- module: prometheus
  period: 10s
  hosts: ["<yba_ip_address>:9090"]
  metricsets: ["query"]
  queries:
  - name: 'yba_up'
    path: '/api/v1/query'
    params:
      query: "up"
```

Verify if the `up` metric can be queried successfully from Elasticsearch. Once successful, you can include more metrics by adding more configs, or by using the [remote_write metricset](https://www.elastic.co/docs/reference/beats/metricbeat/metricbeat-metricset-prometheus-remote_write).

---

## 3. Prometheus

There are four options for sending metrics to Prometheus or a Prometheus-compatible backend (e.g. Cortex, Mimir):
1. Federation
2. Remote Write
3. OTLP
4. Scrape directly from universe nodes

Here's a summary for the first three options:

| Feature                  | Federation                      | Remote Write                            | OTLP Export                                 |
| ------------------------ | ------------------------------- | --------------------------------------- | ------------------------------------------- |
| **Direction**            | Pull (Central scrapes Local)    | Push (Local sends to Central)           | Push (Local sends via standard)             |
| **Best Use Case**        | Global aggregations, low volume | Raw data replication, long-term storage | Vendor-neutral pipelines, unified telemetry |
| **Bandwidth Efficiency** | Low (Text format over HTTP)     | Highest (Remote Write 2.0 compression)  | Moderate                                    |
| **Data Translation**     | None (Native Prometheus)        | None (Native Prometheus)                | Required (Prometheus ↔ OTLP semantics)      |

### Federation

To federate metrics from YBA to your destination Prometheus, follow [these instructions](https://docs.yugabyte.com/stable/yugabyte-platform/alerts-monitoring/prometheus-custom/prometheus-federate/).

### Remote Write

To use Remote Write to send metrics from YBA's embedded Prometheus to your destination Prometheus, configure your `yba-ctl.yml` configuration file with the following section:

```yaml
prometheus:
   remoteWrite:
      enabled: true
      configs: [] # Add your Remote Write config here
```

After editing your configuration, [reconfigure your YBA installation](https://docs.yugabyte.com/stable/yugabyte-platform/install-yugabyte-platform/install-software/installer/#reconfigure) by running `sudo yba-ctl reconfigure`.

### OTLP

To send metrics from YBA to any OTLP-compatible receiver (e.g. Prometheus 3.0+) using the standard OpenTelemetry wire format, follow [this guide](https://docs.yugabyte.com/stable/yugabyte-platform/alerts-monitoring/anywhere-export-configuration/).

---

## 4. SolarWinds

todo