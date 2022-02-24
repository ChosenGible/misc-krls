ruleset manage_sensors {
    meta {
        name "Manage Sensors"
        author "Alex Brown"

        use module io.picolabs.wrangler alias wrangler

        shares sensors, temperatures, threshold_violations, inrange_temperatures, sp_sensor_name, sp_sensor_location, sp_sensor_threshold, sp_alert_phone
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

        //test functions
        sp_sensor_name = function(sensor_id) {
            eci = ent:sensors{[sensor_id, "eci"]}
            wrangler:picoQuery(eci, "sensor_profile", "sensor_name")
        }
        sp_sensor_location = function(sensor_id) {
            eci = ent:sensors{[sensor_id, "eci"]}
            wrangler:picoQuery(eci, "sensor_profile", "sensor_location")
        }
        sp_sensor_threshold = function(sensor_id) {
            eci = ent:sensors{[sensor_id, "eci"]}
            wrangler:picoQuery(eci, "sensor_profile", "sensor_threshold")
        }
        sp_alert_phone = function(sensor_id) {
            eci = ent:sensors{[sensor_id, "eci"]}
            wrangler:picoQuery(eci, "sensor_profile", "alert_phone")
        }

        sensor_temperatures = function(value, key) {
            eci = ent:sensors{[key, "eci"]}
            wrangler:picoQuery(eci, "temperature_store", "temperatures")
        }

        sensor_violations = function(value, key) {
            eci = ent:sensors{[key, "eci"]}
            wrangler:picoQuery(eci, "temperature_store", "threshold_violations")
        }

        sensor_inrange = function(value, key) {
            eci = ent:sensors{[key, "eci"]}
            wrangler:picoQuery(eci, "temperature_store", "inrage_temperatures")
        }

        temperatures = function() {
            ent:sensors.map(sensor_temperatures)
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
        sensor_profile_url = "https://raw.githubusercontent.com/ChosenGible/misc-krls/master/Lab4/sensor_profile.krl"
        //sensor_profile_rid = "sensor_profile_rid"
        emitter_url = "https://raw.githubusercontent.com/windley/temperature-network/main/io.picolabs.wovyn.emitter.krl"
        //emitter_rid = "io.picolabs.wovyn.emitter"

        empty_config = {}
        wovyn_config = {"sid" : meta:rulesetConfig{"sid"}, "token" : meta:rulesetConfig{"token"}}
    }

    rule new_sensor {
        select when sensor new_sensor
        pre {
            sensor_id = event:attrs{"sensor_id"}
            exists = ent:sensors && ent:sensors >< sensor_id
        }
        if not exists then
            send_directive("say", {"Manage Sensors":"Creating new sensor Pico with sensor_id = " + sensor_id})
        fired {
            raise wrangler event "new_child_request"
                attributes {
                    "name" : nameFromID(sensor_id),
                    "backgroundColor" : "#ff0000",
                    "sensor_id" : sensor_id }
        }
    }

    rule existing_sensor {
        select when sensor new_sensor
        pre {
            sensor_id = event:attrs{"sensor_id"}
            exists = ent:sensors && ent:sensors >< sensor_id
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

    rule teardown_sensor_pico {
        select when sensor unneeded_sensor
        pre {
            sensor_id = event:attrs{"sensor_id"}
            exists = ent:sensors >< sensor_id
            sensor_eci = ent:sensors{[sensor_id, "eci"]}
        }
        if exists && sensor_eci then
            send_directive("deleting sensor", {"sensor_id":sensor_id})
        fired {
            raise wrangler event "child_deletion_request"
                attributes { "eci" : sensor_eci };
            clear ent:sensors{sensor_id}
        }
    }

    // rule reset_sensor_manager {
    //     select when sensor reset
    //     always {
    //         ent:sensors := {}
    //     }
    // }


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