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

## 3. SolarWinds

todo