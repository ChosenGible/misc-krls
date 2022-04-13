ruleset temperature_store {
    meta {
        name "Temperature Store"
        author "Alex Brown"

        use module io.picolabs.subscription alias subscription

        shares temperatures, threshold_violations, inrage_temperatures, last_temperature
        provides temperatures, threshold_violations, inrage_temperatures, last_temperature
    }

    global {
        default_threshold = 80

        temperatures = function(){
            ent:temperatures
        }

        last_temperature = function(){
            ent:temperatures[ent:temperatures.length() - 1]
        }

        violation_status = function(){
            ent:violation_status
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

    rule check_if_violating {
        select when wovyn new_temperature_reading
        pre {
            temp = event:attrs{"temperature"}
        }
        if temp > ent:threshold then noop()
        fired {
            ent:violation_status := 1
        }
        else {
            ent:violation_status := 0
        }
    }

    rule clear_temperatures {
        select when sensor reading_reset
        always {
            ent:temperatures := clear_temps
            ent:violations := clear_temps
        }
    }

    rule update_violation_threshold {
        select when sensor threshold_update
        pre {
            threshold = event:attrs{"threshold"}
        }
        if threshold then noop()
        fired {
            ent:threshold := threshold
        }
    }
}