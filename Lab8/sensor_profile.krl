ruleset sensor_profile {
    meta {
        name "Sensor Profile"
        author "Alex Brown"

        use module io.picolabs.wrangler alias wrangler

        shares sensor_name, sensor_location, sensor_threshold, alert_phone, sub_list
        provides sensor_name, sensor_location, sensor_threshold, alert_phone, sub_list
    }

    global {
        clearName = "Not Set"
        clearLocation = "Not Set"
        clearThreshold = "0"
        clearPhone = "+19199997000"

        no_message_num = 0

        sensor_name = function(){
            ent:sensorName
        }
        sensor_location = function(){
            ent:sensorLocation  
        }
        sensor_threshold = function(){
            ent:threshold
        }
        alert_phone = function(){
            ent:phone
        }

        sub_list = function(){
            ent:sub_list
        }
    }

    rule sensor_update {
        select when sensor profile_updated

        pre {
            sensorName = event:attrs{"sensorName"}
            sensorLocation = event:attrs{"sensorLocation"}
            threshold = event:attrs{"threshold"}
            phone = event:attrs{"phoneNumber"}
        }
        send_directive("sensor_profile", {"new name":sensorName, "new location":sensorLocation, "new threshold":threshold})
        always{
            ent:sensorName := sensorName => sensorName | ent:sensorName.defaultsTo(clearName, "Name not initialized");
            ent:sensorLocation := sensorLocation => sensorLocation | ent:sensorLocation.defaultsTo(clearLocation, "Location not initialized");
            ent:threshold := threshold => threshold | ent:threshold.defaultsTo(clearThreshold, "Threshold not initialized");
            ent:phone := phone => phone | ent:phone.defaultsTo(clearPhone, "Phone not initialized");
        }
    }

    rule clear_sensor_details {
        select when sensor clear_profile
        always {
            ent:sensorName := clearName
            ent:sensorLocation := clearLocation
            ent:threshold := clearThreshold
            ent:phone := clearPhone
        }
    }

    rule initialize_ruleset {
        select when wrangler ruleset_installed where event:attr("rids") >< meta:rid
        always {
            ent:sensor_id := random:uuid()
            period = 15
            schedule gossip event "gossip_heartbeat" repeat << */#{period} * * * * * >> attributes {}
        }
    }

    rule setup_subscription {
        select when wrangler inbound_pending_subscription_added
        if event:attrs{"name"} == "gossip_sub" then noop()
        fired {
            req_sensor_id = event:attrs{"req_sensor_id"}
            raise wrangler event "pending_subscription_approval" attributes event:attrs.put("res_sensor_id", ent:sensor_id);
            ent:sub_list := ent:sub_list.defaultsTo([], "first Sub").append({"sensor_id":req_sensor_id})
        }
    }

    rule request_subscription {
        select when gossip setup_new_subscription
        pre {
            wellknownRx = event:attrs{"wellknownRx"}
            sensor_id = ent:sensor_id
        }
        always {
            raise wrangler event "subscription"
                attributes {
                    "name":"gossip_sub",
                    "channel_type":meta:rid,        
                    "wellKnown_Tx": wellknownRx,
                    "req_sensor_id": sensor_id,           
                    "Rx_role":"gossip_node",
                    "Tx_role":"gossip_node"
                }
        }
    }

    rule subscription_added {
        select when wrangler subscription_added
        pre {
            res_sensor_id = event:attrs{"res_sensor_id"}
        }
        if res_sensor_id then noop()
        fired {
            ent:sub_list := ent:sub_list.defaultsTo([], "first Sub").append({"sensor_id":res_sensor_id})
        }
    }
}