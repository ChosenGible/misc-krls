ruleset manage_sensors {
    meta {
        name "Manage Sensors"
        author "Alex Brown"

        use module io.picolabs.wrangler alias wrangler

        shares sensors
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

        wovyn_base_url = "https://raw.githubusercontent.com/ChosenGible/misc-krls/master/Lab9/wovyn_base.krl"
        temperature_store_url = "https://raw.githubusercontent.com/ChosenGible/misc-krls/master/Lab9/temperature_store.krl"
        //sensor_profile_url = "https://raw.githubusercontent.com/ChosenGible/misc-krls/master/Lab9/sensor_profile.krl"
        sensor_profile_url = "file:///home/alexb/pico-rulesets/git-repos/misc-krls/Lab8/sensor_profile.krl"

        empty_config = {}

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
                installRuleset(eci, sensor_id, wovyn_base_url, empty_config)
                installRuleset(eci, sensor_id, temperature_store_url, empty_config)
                installRuleset(eci, sensor_id, sensor_profile_url, empty_config)
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

    rule reset_sensor_manager {
        select when sensor reset
        always {
            ent:sensors := {}
        }
    }

}