## Coralogix Fluentd Buffer Alert

Fluentd uses memory to store buffer chunks, once its buffer is full, it starts throwing exceptions in its logs,
and it means there is a bottleneck, the Fluentd cant tail new logs.
Therefore we recommend creating an alert in Coralogix, that will trigger while Fluentd starts throwing buffer exceptions,
Run the following command in order to create a new alert in Coralogix: 
** `Alerts, Rules and Tags API Key` needs to be inserted in the command
** Notifications emails and integrations need to be updated 

```
curl -X POST https://api.eu2.coralogix.com/api/v1/external/alerts -H "Authorization: bearer <Alerts, Rules and Tags API Key>" -H "Content-Type: application/json" --data-binary '{
        "name": "Fluentd Buffer Full",
        "severity": "critical",
        "is_active": true,
        "log_filter": {
                "text": "BufferOverflow",
                "category": null,
                "filter_type": "text",
                "severity": ["error", "critical"],
                "application_name": ["default"],
                "subsystem_name": ["fluentd"],
                "computer_name": null,
                "class_name": null,
                "ip_address": null,
                "method_name": null
        },
        "condition": {
                "condition_type": "more_than",
                "threshold": 3,
                "timeframe": "5MIN",
                "group_by": "host"
        },
        "notifications": {
                "emails": ["security@mycompany.com", "mgmt@mycompany.com"],
                "integrations": ["myintegration"]
        },
        "notify_every": 60,
        "description": "Fluentd buffer is full, destination capacity is insufficient for your traffic.",
        "active_when": {
                "timeframes": [{
                        "days_of_week": [
                                0,
                                1,
                                2,
                                3,
                                4,
                                5,
                                6
                        ],
                        "activity_ends": "00:00:00",
                        "activity_starts": "00:00:01"
                }]
        }
}'
```