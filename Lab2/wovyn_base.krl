ruleset wovyn_base {
    meta {
        name "Wovyn Base"
        author "Alex Brown"

        use module io.picolabs.wovyn.emitter
        use module twilio_wrapper alias twilio
            with
                sid = meta:rulesetConfig{"sid"}
                token = meta:rulesetConfig{"token"}
    }

    global {
        temperature_threshold = 60.0
    }

    rule process_heartbeat {
        select when wovyn heartbeat

        pre {
            genericThing = event:attrs{"genericThing"}
            temperatureArray = genericThing{["data","temperature"]}
            temperature = temperatureArray[0]{"temperatureF"}
        }

        if event:attrs{"genericThing"} then
        send_directive("say", {"Wovyn Base":"heartbeat event raised " + temperature})

        fired {
            log info "process_heartbeat fired"
            log info temperature
            raise wovyn event "new_temperature_reading" attributes {
                "temperature" : temperature,
                "timestamp": time:now()
            }

        } else {
            log info "process_heartbeat did not fire"
        } 
    }

    rule find_high_temp {
        select when wovyn new_temperature_reading

        if event:attrs{"temperature"} > temperature_threshold then noop()

        fired {
            log info "find_high_temp fired"
            raise wovyn event "threshold_violation" attributes {
                "temperature": event:attrs{"temperature"},
                "timestamp": event:attrs{"timestamp"}
            }
        }
        else {
            log info "find_high_temp did not fire"
        }

    }

    rule threshold_notification {
        select when wovyn threshold_violation
        pre {
            fromPhone = "+17655655074"
            toPhone = "+19199997000"
            message = "temperature of " + event:attrs{"temperature"} + "F was recorded at " + event:attrs{"timestamp"}
        }
        twilio:sendSMS(fromPhone, toPhone, message)
    }
}