ruleset temperature_store {
    meta {
        name "Temperature Store"
        author "Alex Brown"

        use module sensor_profile alias sprofile

        shares temperatures, threshold_violations, inrage_temperatures
        provides temperatures, threshold_violations, inrage_temperatures
    }

    global {
        clear_temps = [{"temperature":60,"timestamp":0}]

        temperature_threshold = sprofile:sensor_threshold()

        temperatures = function(){
            ent:temperatures
        }

        threshold_violations = function(){
            ent:violations
        }

        inrage_temperatures = function(){
            ent:temperatures.filter(function(x) { x{"temperature"} < temperature_threshold })
        }

    }

    rule collect_temperatures {
        select when wovyn new_temperature_reading
        pre {
            recorded_temp = event:attrs{"temperature"}
            recorded_time_stamp = event:attrs{"timestamp"}
        }
        send_directive("collect temps", {"temperature":recorded_temp, "timestamp":recorded_time_stamp})
        always {
            ent:temperatures := ent:temperatures.defaultsTo(clear_temps, "temperatures was not initialized")
            ent:temperatures := ent:temperatures.append({"temperature":recorded_temp,"timestamp":recorded_time_stamp})
        }
    }

    rule collect_threshold_violations {
        select when wovyn threshold_violation
        pre {
            recorded_temp = event:attrs{"temperature"}
            recorded_time_stamp = event:attrs{"timestamp"}
        }
        send_directive("collect violations", {"temperature":recorded_temp, "timestamp":recorded_time_stamp})
        always {
            ent:violations := ent:violations.defaultsTo(clear_temps, "temperatures was not initialized")
            ent:violations := ent:violations.append({"temperature":recorded_temp,"timestamp":recorded_time_stamp})
        }
    }

    rule clear_temperatures {
        select when sensor reading_reset
        always {
            ent:temperatures := clear_temps
            ent:violations := clear_temps
        }
    }

    rule generate_report {
        select when sensor generate_report
        pre {
            recent_temp = ent:temperatures.index(ent:temperatures.length() - 1)
        }
        always {
            raise wrangler event "send_event_on_subs"
                attributes {
                    "domain":"sensor",
                    "type":"report",
                    "Tx_role":"manager",
                    "attrs":{
                        "recent_tempt":recent_temp,
                        "sensor_Rx":subscription:Wellknown_Rx
                    }
                }
        }
    }
}