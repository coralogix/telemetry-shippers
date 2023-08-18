# Fluent Bit

Coralogix provides seamless integration with Fluent Bit so you can send your logs from anywhere and parse them according to your needs.

**Note**! Coralogix supports Fluent Bit **v2.0.7** and onwards.

## Prerequisites

- Fluent Bit [installed](https://docs.fluentbit.io/manual/installation/getting-started-with-fluent-bit)

## Usage

You must provide the following four environment variables when the fluent bit integration.

**Private_Key** –  Your [Send-Your-Data API key](https://coralogix.com/docs/send-your-data-api-key/) is a unique ID that represents your Coralogix team. Input the key **without** quotation marks or apostrophes.

**Application_Name** – The name of your [application](https://coralogix.com/docs/application-and-subsystem-names/), as it will appear in your Coralogix dashboard. For example, a company named SuperData might insert the `SuperData` string parameter.  If SuperData wants to debug its test environment, it might use `SuperData–Test`.

**SubSystem_Name** – The name of your [subsystem](https://coralogix.com/docs/application-and-subsystem-names/), as it will appear in your Coralogix dashboard. Applications often have multiple subsystems (ie. Backend Servers, Middleware, Frontend Servers, etc.).  In order to help you examine the data you need, inserting the subsystem parameter is vital.

**Endpoint** - Find the endpoint [here](https://coralogix.com/docs/coralogix-endpoints/) matching your Coralogix domain. Example: `ingress.coralogix.com`

## Configuration

Open your existing `Fluent-Bit` configuration file and add the following:

```
[FILTER]
        Name            nest
        Match           *
        Operation       nest
        Wildcard        *
        Nest_under      text
[FILTER]
        Name            modify
        Match           *
        Add             applicationName ${Application_Name}
        Add             subsystemName ${SubSystem_Name}
        Add             computerName ${HOSTNAME}
[OUTPUT]
        Name            http
        Match           *
        Host            ${Endpoint}
        Port            443
        URI             /logs/rest/singles
        Format          json_lines
        TLS             On
        Header          private_key ${Private_Key}
        compress        gzip
        Retry_Limit     10
```

### Application and Subsystem Name

If you wish to set your [application and subsystem names](https://coralogix.com/docs/application-and-subsystem-names/) as a fixed value, use Application_Name and SubSystem_Name as described above in your configuration file. If you want to set your Application Name or Subsystem name to the input tag or if your input stream is a `JSON` object, you can extract from them by including some LUA filters.

Example:

```
[FILTER]
    Name            lua
    Match           *
    call            applicationNameFromEnv
    code            function applicationNameFromEnv(tag, timestamp, record) record["applicationName"] = record["metadata"]["computerName"] or os.getenv("Application_Name") return 2, timestamp, record end

[FILTER]
    Name            lua
    Match           *
    call            subsystemNameFromEnv
    code            function subsystemNameFromEnv(tag, timestamp, record) record["subsystemName"] = tag or os.getenv("SubSystem_Name") return 2, timestamp, record end
```

For instance, with the bellow `JSON` `new_record["applicationName"] = record["application"]` will extract "*testApp*" into Coralogix applicationName.

```
{
    "application": "testApp",
    "subsystem": "testSub",
    "code": "200",
    "stream": "stdout",
    "timestamp": "2016-07-20T17:05:17.743Z",
    "message": "hello_world",
}
```

- Note that nested JSONs are supported so you can extract nested values as your `applicationName` and/or `subsystemName`.

**If you need additional support or have any questions, our support team is available to you 24/7 via our in-app chat.**