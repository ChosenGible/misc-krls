ruleset sensor_profile {
    meta {
        name "Sensor Profile"
        author "Alex Brown"

        use module io.picolabs.wrangler alias wrangler

        shares sensor_name, sensor_location, sensor_threshold, alert_phone, sub_list, smart_tracker, recorded_rumors, get_peer, prepare_rumor, prepare_seen
        provides sensor_name, sensor_location, sensor_threshold, alert_phone, sub_list, smart_tracker, recorded_rumors, get_peer, prepare_rumor, prepare_seen
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

        /*
        Smart Tracker schema:
        {
            {<SID>:
                {<SID>:<SeqNum>,...}
            },
            ...
        }
        */
        smart_tracker = function(){
            ent:smart_tracker
        }

        /*
        Rumor Log schema:
        {
            {<SID>:
                {
                    <MID>:<Rumor>,...
                }
            }
        } 
        */
        recorded_rumors = function(){
            ent:rumor_logs
        }

        // get_next_seq_num = function(sensor_id, other_sub_id){
        //     sub_logs = ent:rumor_logs{sensor_id}
        //     get_next_seq_num_rec(sub_logs, other_sub_id, 0)
        // }

        // get_next_seq_num_rec = function(sub_logs, other_sub_id, check_num){
        //     check_num >< ent:sub_logs.filter(function(v, k){ v{"SensorID"} == other_sub_id }) => get_next_seq_num_rec(sub_logs, other_sub_id, check_num + 1) | check_num
        // }

        get_peer = function(){
            self_seen = prepare_seen()
            needy_peers = ent:smart_tracker.filter(function(v,k){
                missing_sensor = self_seen.filter(function(sv,sk){v{sk} == null})
                behind_self = self_seen.filter(function(sv,sk){v{sk} < sv})
                missing_sensor || behind_self
            })
            needy_peers.keys()[random:integer(upper = needy_peers.keys().length(), lower = 0)]
        }

        /* 
        syntax of message returned by prepare_message:
        {
            type: <rumor | seen>
            body: { depends on which type is used }
        }

        attrs for rumor:
        {
            "MessageID" : "<SID>:<SeqNum>",
            "SensorID" : <SID>,
            "SeqNum" : <SeqNum>,
            "Temperature" : <Temp>,
            "Timestamp" : <Timestamp>
        }

        attrs for seen:
        {
            <ID>:<SeqNum>
            ...
        }
        
        */

        prepare_rumor_body = function(sensor_id){
            sensor_seen = ent:smart_tracker{sensor_id}
            self_seen = prepare_seen()

            messages_needed = self_seen.filter(function(sv,sk){
                sensor_seen{sk} == null || sensor_seen{sk} < sv
            })

            message_selected = messages_needed.keys().head()
            message_id = message_selected + ":" + messages_needed{message_selected}

            ent:rumor_logs{[message_selected, message_id]}
        }

        prepare_rumor = function(sensor_id){
            {"type":"rumor", "body":prepare_rumor_body(sensor_id)}
        }

        prepare_seen_body = function(){
            ent:rumor_logs.map(function(v,k) {
                seq_num = -1
                seq_message = v.values().reduce(function(a,b) {
                    b{"SeqNum"} == a{"SeqNum"} + 1 => b | a
                })
                seq_message{"SeqNum"}
            })
        }

        prepare_seen = function(sensor_id){
            {"type":"seen","body": prepare_seen_body()}
        }

        prepare_message = function(sensor_id){
            random:integer(upper = 1, lower = 0) == 1 => prepare_rumor(sensor_id) | prepare_seen(sensor_id)
        }

        send_message = defaction(sensor_id, message){
            sub_id = ent:sub_list{[sensor_id, "bus", "Id"]}
            m_type = message{["type"]}
            body = message{["body"]}

            event:send(
                {
                    "eci" : meta:eci,
                    "domain" : "wrangler",
                    "type" : "send_event_on_subs",
                    "attrs" : {
                        "domain" : "gossip",
                        "type" : m_type,
                        "subID" : sub_id,
                        "attrs" : {"sensorID" : ent:sensor_id, "body" : body}
                    }
                }
            )
        }

        update = defaction(sensor_id, message){
            event:send(
                {
                    "eci" : meta:eci,
                    "domain" : "gossip",
                    "type" : "update_smart_tracker",
                    "attrs" : {
                        "type" : message{"type"},
                        "sensorID":sensor_id,
                        "message" : message{"body"}
                    }
                }
            )
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
    // MANUAL MODE
    rule self_temp_log_report {
        select when wovyn new_temperature_reading_manual
        pre {
            temp = event:attrs{"temperature"}
            time = event:attrs{"timestamp"}
            origin_id = random:uuid()
            self_seq_num = ent:seq_num.defaultsTo(no_message_num, "first log")
            self_sensor_id = ent:sensor_id
            message_id = self_sensor_id + ":" + ent:seq_num.defaultsTo(0, "first log")

        }
        if temp && time then noop()
        fired {
            raise gossip event "rumor"
                attributes {
                    "sensorID":self_sensor_id,
                    "body": {
                        "MessageID" : message_id,
                        "SensorID" : self_sensor_id,
                        "SeqNum" : self_seq_num,
                        "Temperature" : temp,
                        "Timestamp" : time
                    }
                }
            ent:seq_num := self_seq_num + 1
        }
    }

    // AUTO MODE
    // rule self_temp_log_report {
    //     select when wovyn new_temperature_reading
    //     pre {
    //         temp = event:attrs{"temperature"}
    //         time = event:attrs{"timestamp"}
    //         origin_id = random:uuid()
    //         self_seq_num = ent:seq_num.defaultsTo(no_message_num, "first log")
    //         self_sensor_id = ent:sensor_id
    //         message_id = self_sensor_id + ":" + ent:seq_num

    //     }
    //     if temp && time then noop()
    //     fired {
    //         raise gossip event rumor
    //             attributes {
    //                 "sensorID":self_sensor_id,
    //                 "body": {
    //                     "MessageID" : message_id,
    //                     "SensorID" : self_sensor_id,
    //                     "SeqNum" : self_seq_num,
    //                     "Temperature" : temp,
    //                     "Timestamp" : time
    //                 }
    //             }
    //         ent:seq_num := self_seq_num + 1
    //     }
    // }

    rule initialize_ruleset {
        select when wrangler ruleset_installed where event:attrs{"rids"} >< meta:rid
        always {
            ent:sensor_id := random:uuid()
            ent:rumor_logs := {}
            ent:smart_tracker := {}
            period = 30
            schedule gossip event "gossip_heartbeat" repeat << */#{period} * * * * * >> attributes {}
        }
    }

    rule send_gossip_message {
        select when gossip gossip_heartbeat
        pre {
            g_sub_id = get_peer()
            message = prepare_message(g_sub_id)
        }
        if g_sub_id && g_sub_id >< ent:sub_list then
            every {
                send_message(g_sub_id, message)
                update(g_sub_id, message)
            }
    }

    rule update_after_rumor_sent {
        select when gossip update_smart_tracker
        pre {
            type = event:attrs{"type"}
            sensor_id = event:attrs{"sensorID"}
            message = event:attrs{"message"}
        }
        if type == "rumor" then noop()
        fired {
            o_sensor_id = message{"SensorID"}
            new_seq_num = message{"SeqNum"}
            ent:smart_tracker{[sensor_id, o_sensor_id]} := new_seq_num
        }
    }

    rule add_rumor_to_discovered_sensor {
        select when gossip discovered_new_sensor
        pre {
            sensor_id = event:attrs{"SensorID"}
            rumor = event:attrs{"rumor"}
        }
        always {
            ent:rumor_logs := ent:rumor_logs.put(sensor_id, {}.put(rumor{"MessageID"}, rumor))
        }
    }

    rule add_rumor_to_existing_sensor {
        select when gossip add_rumor_to_sensor
        pre {
            sensor_id = event:attrs{"SensorID"}
            rumor = event:attrs{"rumor"}
            is_already_logged = rumor{"MessageID"} >< ent:rumor_logs{sensor_id}
        }
        if rumor && not is_already_logged then noop()
        fired {
            ent:rumor_logs := ent:rumor_logs{sensor_id}.put({}.put(rumor{"MessageID"}, rumor))
        }
    }

    rule recieved_gossip_rumor {
        select when gossip rumor
        pre {
            rumor = event:attrs{"body"}
            sensor_id = rumor{"SensorID"}
            message_id = rumor{"MessageID"}
            is_existing_sensor = sensor_id >< ent:rumor_logs
        }
        if rumor && is_existing_sensor then noop()
        fired {
            ent:rumor_logs{sensor_id} := {}.put(message_id, rumor)
        }
    }
    //         raise gossip event "add_rumor_to_sensor"
    //             attributes {
    //                 "SensorID" : rumor{"SensorID"},
    //                 "rumor" : rumor
    //             }
    //     }
    //     else {
    //         raise gossip event "discovered_new_sensor"
    //             attributes {
    //                 "SensorID" : rumor{"SensorID"},
    //                 "rumor" : rumor
    //             }
    //     }
    // }

    rule recieved_gossip_seen {
        select when gossip seen
        pre {
            o_sensor_id = event:attrs{"sensorID"}
            body = event:attrs{"body"}
        }
        if body then noop()
        fired {
            ent:smart_tracker{o_sensor_id} := body
        }
    }

    rule setup_subscription {
        select when wrangler inbound_pending_subscription_added
        if event:attrs{"name"} == "gossip_sub" then noop()
        fired {
            req_sensor_id = event:attrs{"req_sensor_id"}
            raise wrangler event "pending_subscription_approval" attributes event:attrs.put("res_sensor_id", ent:sensor_id);
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
            ent:sub_list := ent:sub_list.defaultsTo({}, "first Sub").put(res_sensor_id, event:attrs{"bus"})
        }
    }

    rule clear_logs {
        select when debug clear_rumor_logs
        always {
            ent:rumor_logs := {}
        }
    }

    rule clear_smart_tracker {
        select when debug clear_smart_tracker
        always {
            ent:smart_tracker := {}
        }
    }

    rule clear_seq_num {
        select when debug clear_seq_num 
        always {
            ent:seq_num := 0
        }
    }
}