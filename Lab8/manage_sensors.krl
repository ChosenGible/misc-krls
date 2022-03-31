ruleset manage_sensors {
    meta {
        name "Manage Sensors"
        author "Alex Brown"

        use module io.picolabs.wrangler alias wrangler
        use module manager_profile alias mprofile
            with
                sid = meta:rulesetConfig{"sid"}
                token = meta:rulesetConfig{"token"}

        shares sensors, temperatures, threshold_violations, inrange_temperatures, sp_sensor_name, sp_sensor_location, sp_sensor_threshold, sp_alert_phone, display_reports
    }

    global {
        nameFromID = function(sensor_id) {
            "Sensor " + sensor_id + " Pico"
        }
        installRuleset = defaction(eci, sensor_id, ruleset_url, config) {
            event:send(
                {
                    "eci" : eci,
                    "eid" : "install-ruleset",
                    "domain" : "wrangler",
                    "type" : "install_ruleset_request",
                    "attrs" : {
                        "url" : ruleset_url,
                        "config" : config,
                        "sensor_id" : sensor_id
                    }
                }
            )
        }

        updateSensorInfo = defaction(eci, sensor_name, sensor_location, sensor_threshold, sensor_phone){
            event:send(
                {
                    "eci" : eci,
                    "eid" : "update-sensor",
                    "domain" : "sensor",
                    "type" : "profile_updated",
                    "attrs" : {
                        "sensorName" : sensor_name,
                        "sensorLocation" : sensor_location,
                        "threshold" : sensor_threshold,
                        "phoneNumber" : sensor_phone
                    }
                }
            )
        }

        sensors = function() {
            ent:sensors
        }

        // sub_sensors = function() {
        //     ent:sensors_subs
        // }

        display_reports = function() {
            numReports = ent:report_log.length()
            ent:report_log.slice(numReports - 5, numReports - 1)
        }

        //test functions
        sp_sensor_name = function(sensor_id) {
            eci = ent:sensors_subs{[sensor_id, "Tx"]}
            wrangler:picoQuery(eci, "sensor_profile", "sensor_name")
        }
        sp_sensor_location = function(sensor_id) {
            eci = ent:sensors_subs{[sensor_id, "Tx"]}
            wrangler:picoQuery(eci, "sensor_profile", "sensor_location")
        }
        sp_sensor_threshold = function(sensor_id) {
            eci = ent:sensors_subs{[sensor_id, "Tx"]}
            wrangler:picoQuery(eci, "sensor_profile", "sensor_threshold")
        }
        sp_alert_phone = function(sensor_id) {
            eci = ent:sensors_subs{[sensor_id, "Tx"]}
            wrangler:picoQuery(eci, "sensor_profile", "alert_phone")
        }

        sensor_temperatures = function(value, key) {
            eci = ent:sensors_subs{[key, "Tx"]}
            wrangler:picoQuery(eci, "temperature_store", "temperatures")
        }

        sensor_violations = function(value, key) {
            eci = ent:sensors_subs{[key, "Tx"]}
            wrangler:picoQuery(eci, "temperature_store", "threshold_violations")
        }

        sensor_inrange = function(value, key) {
            eci = ent:sensors_subs{[key, "Tx"]}
            wrangler:picoQuery(eci, "temperature_store", "inrage_temperatures")
        }

        temperatures = function() {
            ent:sensors_subs.map(sensor_temperatures)
        }

        threshold_violations = function() {
            ent:sensors.map(sensor_violations)
        }

        inrange_temperatures = function() {
            ent:sensors.map(sensor_inrange)
        }


        twillio_url = "https://raw.githubusercontent.com/ChosenGible/misc-krls/master/Lab1/twilio_wrapper.krl"
        wovyn_base_url = "https://raw.githubusercontent.com/ChosenGible/misc-krls/master/Lab2/wovyn_base.krl"
        //wovyn_base_rid = "wovyn_base"
        temperature_store_url = "https://raw.githubusercontent.com/ChosenGible/misc-krls/master/Lab3/temperature_store.krl"
        //temperature_store_rid = "temperature_store"
        //sensor_profile_url = "https://raw.githubusercontent.com/ChosenGible/misc-krls/master/Lab8/sensor_profile.krl"
        sensor_profile_url = "file:///home/alexb/pico-rulesets/git-repos/misc-krls/Lab8/sensor_profile.krl"
        //sensor_profile_rid = "sensor_profile_rid"
        emitter_url = "https://raw.githubusercontent.com/windley/temperature-network/main/io.picolabs.wovyn.emitter.krl"
        //emitter_rid = "io.picolabs.wovyn.emitter"

        empty_config = {}
        wovyn_config = {"sid" : meta:rulesetConfig{"sid"}, "token" : meta:rulesetConfig{"token"}}

        clear_report_log = []
    }

    rule new_sensor {
        select when sensor new_sensor
        pre {
            sensor_id = event:attrs{"sensor_id"}
            exists = ent:sensors_subs && ent:sensors_subs >< sensor_id
        }
        if not exists then
            send_directive("say", {"Manage Sensors":"Creating new sensor Pico with sensor_id = " + sensor_id})
        fired {
            raise wrangler event "new_child_request"
                attributes {
                    "name" : nameFromID(sensor_id),
                    "backgroundColor" : "#6a0dad",
                    "sensor_id" : sensor_id }
        }
    }

    rule existing_sensor {
        select when sensor new_sensor
        pre {
            sensor_id = event:attrs{"sensor_id"}
            exists = ent:sensors_subs && ent:sensors_subs >< sensor_id
        }
        if exists then 
            send_directive("say", {"Manage Sensors":"Found exisitng sensor Pico with sensor_id = " + sensor_id + ", could not create new sensor Pico"})
    }

    rule setup_new_sensor {
        select when wrangler new_child_created
        pre {
            sensor_id = event:attrs{"sensor_id"}
            eci = event:attrs{"eci"}
            //name = event:attrs{"name"}
            wellKnown_Rx = ctx:query(eci, "io.picolabs.subscription","wellKnown_Rx"){"id"}
        }
        if sensor_id then
            every {
                send_directive("install rulesets start", {"eci" : eci})
                installRuleset(eci, sensor_id, emitter_url, empty_config)
                installRuleset(eci, sensor_id, sensor_profile_url, empty_config)
                installRuleset(eci, sensor_id, twillio_url, empty_config)
                installRuleset(eci, sensor_id, wovyn_base_url, wovyn_config)
                installRuleset(eci, sensor_id, temperature_store_url, empty_config)
                updateSensorInfo(eci, "sim sensor", "simulation", 80, "+19199997000")
                send_directive("install rulesets end", {"eci" : eci})
            }
        fired {
            ent:sensors{sensor_id} := { "eci": eci };
        }

    }

    // rule new_subscription {
    //     select when sensor finished_ruleset_install
    //     pre {
    //         child_wellKnown_Rx = event:attrs{"wellKnown_Rx"}
    //         sensor_id = event:attrs{"sensor_id"}
    //     }
    //     always {
    //         raise wrangler event "subscription"
    //             attributes {
    //                 "name":"parent_sub",
    //                 "channel_type":meta:rid,        
    //                 "wellKnown_Tx": child_wellKnown_Rx,
    //                 "sensor_id": sensor_id,           
    //                 "Rx_role":"manager",
    //                 "Tx_role":"sensor"
    //             }
    //     }
    // }

    // rule setup_subscription {
    //     select when wrangler subscription_added
    //     pre {
    //         sensor_id = event:attrs{"sensor_id"}
    //         sub_id = event:attrs{"Id"}
    //         sub_info = event:attrs{"bus"}.put("sensor_id", sensor_id)
    //     }
    //     always {
    //         ent:sensors_subs{sensor_id} := sub_info.put("sensor_id", sensor_id)
    //     }
    // }

    rule teardown_sensor_pico {
        select when sensor unneeded_sensor
        pre {
            sensor_id = event:attrs{"sensor_id"}
            exists = ent:sensors >< sensor_id
            //sub_id = ent:sensors_subs{[sensor_id, "Id"]}
        }
        if exists then
            send_directive("deleting sensor", {"sensor_id":sensor_id})
        fired {
            raise wrangler event "child_deletion_request"
                attributes ent:sensors{sensor_id};
            clear ent:sensors{sensor_id}
            //clear ent:sensors_subs{sensor_id}
        }
    }

    rule threshold_notification {
        select when sensor threshold_violation
        pre {
            temperature = event:attrs{"temperature"}
            timestamp = event:attrs{"timestamp"}
            message = "FROM MANAGER: Temperature of " + temperature + "F was recorded at " + timestamp
        }
        mprofile:sendSMS(message)
    }

    // rule request_report {
    //     select when sensor report_request
    //     pre {
    //         corelation_id = ent:new_id.defaultsTo(0, "new_id not set")
    //     }
    //     always {
    //         raise wrangler event "send_event_on_subs"
    //             attributes {
    //                 "domain":"sensor",
    //                 "type":"generate_report",
    //                 "Tx_role":"sensor",
    //                 "attrs":{
    //                     "core_id":corelation_id
    //                 }
                    
    //             }
    //         ent:new_id := ent:new_id.defaultsTo(0, "new_id not set") + 1
    //     }
    // }

    // rule recieve_report {
    //     select when sensor report
    //     pre {
    //         recent_temp = event:attrs{"recent_temp"}
    //         core_id = event:attrs{"core_id"}

    //         report = {"temp":recent_temp,"sensorRx":meta:eci, "corelation_id":core_id}
    //     }
    //     if recent_temp then noop()
    //     fired {
    //         ent:report_log := ent:report_log.defaultsTo(clear_report_log, "report log not set")
    //         ent:report_log := ent:report_log.append(report)
    //     }
    // }

    rule reset_sensor_manager {
        select when sensor reset
        always {
            ent:sensors := {}
        }
    }


    //test rules
    rule sp_sensor_update {
        select when sensor profile_update_test
        pre {
            sensor_id = event:attrs{"sensorID"}
            exists = ent:sensors && ent:sensors >< sensor_id
            sensor_eci = ent:sensors{[sensor_id, "eci"]}
            sensor_name = event:attrs{"sensorName"}
            sensor_location = event:attrs{"sensorLocation"}
            sensor_threshold = event:attrs{"threshold"}
            sensor_phone = event:attrs{"phoneNumber"}
        }
        if exists && sensor_eci then
            updateSensorInfo(sensor_eci, sensor_name, sensor_location, sensor_threshold, sensor_phone)
    }

    rule wb_fabricate_heartbeat{
        select when sensor test_heartbeat
        pre {
            sensor_id = event:attrs{"sensorID"}
            exists = ent:sensors && ent:sensors >< sensor_id
            sensor_eci = ent:sensors{[sensor_id, "eci"]}
            genericThing = event:attrs{"genericThing"}
        }
        if exists && sensor_eci then
            event:send(
                {
                    "eci" : sensor_eci,
                    "eid" : "test-heartbeat",
                    "domain" : "wovyn",
                    "type" : "heartbeat",
                    "attrs" : {
                        "genericThing" : genericThing
                    }
                }
            )
    }

    rule wb_fabricate_new_reading{
        select when sensor test_reading
        pre {
            sensor_id = event:attrs{"sensorID"}
            exists = ent:sensors && ent:sensors >< sensor_id
            sensor_eci = ent:sensors{[sensor_id, "eci"]}
            temp = event:attrs{"temperature"}
            timestamp = event:attrs{"timestamp"}
        }
        if exists && sensor_eci then
            event:send(
                {
                    "eci" : sensor_eci,
                    "eid" : "test-reading",
                    "domain" : "wovyn",
                    "type" : "new_temperature_reading",
                    "attrs" : {
                        "temperature" : temp,
                        "timestamp" : timestamp
                    }
                }
            )
    }
}