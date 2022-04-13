ruleset wovyn_base {
    meta {
        name "Wovyn Base"
        author "Alex Brown"
    }

    rule manual_reading {
        select when debug temperature_report
        pre {
            temperature = event:attrs{"temperature"}
            timestamp = event:attrs{"timestamp"}
        }
        always {
            raise wovyn event "new_temperature_reading" attributes {
                "temperature" : temperature,
                "timestamp": time:now()
            }
        }
    }
}