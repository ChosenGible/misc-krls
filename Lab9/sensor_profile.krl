ruleset sensor_profile {
    meta {
        name "Sensor Profile"
        author "Alex Brown"

        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subs
        use module temperature_store alias store

        shares smart_tracker, recorded_rumors, get_peer, prepare_rumor, prepare_seen, prepare_violation_message, violation_rumors, violation_tracker, get_peer_violation, violation_tracker_per_sub, num_current_violations
        provides smart_tracker, recorded_rumors, get_peer, prepare_rumor, prepare_seen, prepare_violation_message, violation_rumors, violation_tracker, get_peer_violation, violation_tracker_per_sub, num_current_violations
    }

    global {
        clearName = "Not Set"
        clearLocation = "Not Set"
        clearThreshold = "0"
        clearPhone = "+19199997000"

        no_message_num = 0

         /*
        threshold_rumors
        {
            <SID>:
                {
                    <SeqNum>:<StatusIncrement>
                },
            
        }
        */
        violation_rumors = function() {
            ent:violations
        }

        sum_sensor_violations = function(sensor_id){
            ent:violations{sensor_id}.values().reduce(function(a,b){a + b})
        }

        num_current_violations = function() {
            ent:violations.map(v,k) {sum_sensor_violations(k)}.values().reduce(function(a,b){a + b})
        }

        /*
        seen_violations
        {
            {<SID>:
                <SID>:<SeqNum>
                ...
            }
        }
         */
        violation_tracker = function(){
            ent:violation_tracker
        }

        violation_tracker_per_sub = function(sub_id){
            ent:violation_tracker{sub_id}
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
            choice = needy_peers.keys()[random:integer(upper = needy_peers.keys().length() - 1, lower = 0)]
            choice => choice | subs:established()[random:integer(upper = subs:established().length() - 1, lower = 0)]{"Id"} // incase we have not gotten any smart_trackers yet
        }

        //TODO REDO
        get_peer_violation = function(current_violation_status) {
            needy_peers = ent:violation_tracker.filter(function(v,k){
                not(current_violation_status == v)
            }).klog("needy_peers:")
            choice = needy_peers.length() > 0 => needy_peers.keys()[random:integer(upper = needy_peers.keys().length() - 1, lower = 0)] | subs:established()[random:integer(upper = subs:established().length() - 1, lower = 0)]{"Id"}
            choice.klog()
        }

        /* 
        syntax of message returned by prepare_message:
        {
            type: <rumor | seen | violation_increment >
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
            <SID>:<SeqNum>,
            ...
        }

        attrs for violation_increment
        {
            "SensorID" : <SID>,
            "SeqNum" : <SeqNum>,
            "Increment" : <StatusIncrement>
        }

        attrs for violation_seen
        {
            <SID>:<SeqNum>,
            ...
        }
        */

        prepare_rumor_body = function(sensor_id){
            sensor_seen = ent:smart_tracker{sensor_id}.klog("0") // this is null wait
            self_seen = prepare_seen_body().klog("1")

            messages_needed = self_seen.filter(function(sv,sk){
                sensor_seen{sk} == null || sensor_seen{sk} < sv
            }).klog("2")

            message_selected = messages_needed.keys().head().klog("3")
            message_id = message_selected + ":" + (sensor_seen{message_selected}.defaultsTo(-1, "Code is better readable") + 1)

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

        prepare_seen = function(){
            {"type":"seen","body": prepare_seen_body()}
        }

        prepare_message = function(sensor_id){
            random:integer(upper = 1, lower = 0) == 1 => prepare_rumor(sensor_id) | prepare_seen()
        }

        prepare_violation_rumor_body_json = function(sid, seq_num){
            {"SensorID":sid, "SeqNum": seq_num, "Increment": ent:violations{[sid, seq_num]}}  
        }

        prepare_violation_rumor_body = function(sensor_id) {
            sensor_violations_seen = ent:violation_tracker{sensor_id}
            self_violations_seen = prepare_violation_seen_body()

            messages_need = self_violations_seen.filter(function(sv,sk){
                sensor_violations_seen{sk} == null || sensor_seen{sk} < sv
            })

            message_selected_sid = messages_needed.keys().head()
            message_selected_seq_num = messages_needed{message_selected_sid}
            prepare_violation_rumor_body_json(message_selected_sid, message_selected_seq_num)
        }

        prepare_violation_rumor = function(sensor_id){            
            {"type":"violation_rumor", "body": {"status": prepare_violation_body(sensor_id)} }
        }

        prepare_violation_seen_body = function(){
            ent:violations.map(function(v,k) {
                seq_num = -1
                seq_message = v.keys().reduce(function(a,b) {
                    b == a + 1 => b | a
                })
                seq_message
            })
        }

        prepare_violation_seen = function() {
            {"type":"violation_seen", "body": prepare_violation_seen_body()}
        }

        prepare_violation_message = function(sensor_id) {
            random:integer(upper = 1, lower = 0) == 1 => prepare_violation_rumor(sensor_id) | prepare_violation_seen(sensor_id)
        }

    //     send_message = defaction(sensor_id, message){
    //         sub_id = ent:sub_list{[sensor_id, "bus", "Id"]}
    //         m_type = message{["type"]}
    //         body = message{["body"]}

    //         event:send(
    //             {
    //                 "eci" : meta:eci,
    //                 "domain" : "wrangler",
    //                 "type" : "send_event_on_subs",
    //                 "attrs" : {
    //                     "domain" : "gossip",
    //                     "type" : m_type,
    //                     "subID" : sub_id,
    //                     "attrs" : {"body" : body}
    //                 }
    //             }
    //         )
    //     }

    //     update = defaction(sensor_id, message){
    //         event:send(
    //             {
    //                 "eci" : meta:eci,
    //                 "domain" : "gossip",
    //                 "type" : "update_smart_tracker",
    //                 "attrs" : {
    //                     "type" : message{"type"},
    //                     "sensorID":sensor_id,
    //                     "message" : message{"body"}
    //                 }
    //             }
    //         )
    //     }
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

            raise sensor event "threshold_update"
                attributes {
                    "threshold": ent:threshold
                }
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
    // rule self_temp_log_report {
    //     select when wovyn new_temperature_reading_manual
    //     pre {
    //         temp = event:attrs{"temperature"}
    //         time = event:attrs{"timestamp"}
    //         origin_id = random:uuid()
    //         self_seq_num = ent:seq_num.defaultsTo(no_message_num, "first log")
    //         self_sensor_id = ent:sensor_id
    //         message_id = self_sensor_id + ":" + ent:seq_num.defaultsTo(0, "first log")

    //     }
    //     if temp && time then noop()
    //     fired {
    //         raise gossip event "rumor"
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

    // AUTO MODE
    rule self_temp_log_report {
        select when wovyn new_temperature_reading
        pre {
            temp = event:attrs{"temperature"}
            time = event:attrs{"timestamp"}
            origin_id = random:uuid()
            self_seq_num = ent:seq_num.defaultsTo(no_message_num, "first log")
            self_sensor_id = ent:sensor_id
            message_id = self_sensor_id + ":" + ent:seq_num
            self_thresh_seq_num = ent:thresh_seq_num.defaultsTo(no_message_num, "first log")
            self_increment = sum_sensor_violations(self_sensor_id) == store:violation_status() => 0 | store:violation_status() => 1 | -1

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
            raise gossip event "violation_rumor"
                attributes {
                    "sensorID":self_sensor_id,
                    "body": {
                        "SensorID": self_sensor_id,
                        "SeqNum": self_thresh_seq_num,
                        "Increment" : self_increment
                    }
                }
         }
    }

    rule initialize_ruleset {
        select when wrangler ruleset_installed where event:attrs{"rids"} >< meta:rid
        always {
            ent:sensor_id := random:uuid()
            ent:rumor_logs := {}
            ent:smart_tracker := {}
            ent:violation_tracker := {}
            ent:violations := {}
            period = 0
            schedule gossip event "gossip_heartbeat" repeat << */#{period} * * * * * >> attributes {}
        }
    }

    rule set_heartbeat_time {
        select when debug heartbeat_update
        pre {
            period = event:attrs{"period"}
        }
        if period then noop()
        fired {
            schedule gossip event "gossip_heartbeat" repeat << */#{period} * * * * * >> attributes {}
        }
    }

    rule spilt_hearbeat_type {
        select when gossip gossip_heartbeat
        pre {
            x = random:integer(upper = 1, lower = 0)
        }
        if x == 1 then noop()
        fired {
            raise gossip event "gossip_other_message"
        }
        else {
            raise gossip event "gossip_threshold_message"
        }
    }

    rule send_threshold_message {
        select when gossip gossip_threshold_message
        pre {
            sub_id = get_peer_violation(violation_status).klog("here 2")
            message = prepare_violation_message(sub_id).klog("here 3")
        }
        if sub_id then noop()
        fired {
            m_type = message{["type"]}
            body = message{["body"]}
            raise wrangler event "send_event_on_subs"
            attributes {
                "domain" : "gossip",
                "type" : m_type,
                "subID" : sub_id,
                "attrs" : {"body":body}
                } if(body)
            raise gossip event "update_violation_tracker" 
                attributes {
                    "type" : m_type,
                    "sensorID":sub_id,
                    "message" : body
                } if (body)
        }
    }

    rule send_gossip_message {
        select when gossip gossip_other_message
        pre {
            sub_id = get_peer()
            message = prepare_message(sub_id)
        }
        if sub_id then noop()
        fired {
            m_type = message{["type"]}
            body = message{["body"]}
            raise wrangler event "send_event_on_subs"
                attributes {
                    "domain" : "gossip",
                    "type" : m_type,
                    "subID" : sub_id,
                    "attrs" : {"body":body}
                } if(body)
            raise gossip event "update_smart_tracker" 
                attributes {
                    "type" : m_type,
                    "sensorID":sub_id,
                    "message" : body
                } if (body)
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

    rule update_after_violation_sent {
        select when gossip update_violation_tracker
        pre {
            type = event:attrs{"type"}
            sensor_id = event:attrs{"sensorID"}
            message = event:attrs{"message"}
        }
        if type == "violation_rumor" then noop()
        fired {
            o_sensor_id = message{"SensorID"}
            new_seq_num = message{"SeqNum"}
            ent:violation_tracker{[sensor_id, o_sensor_id]} := new_seq_num
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
        if rumor then noop()
        fired {
            sensor_logs = ent:rumor_logs{sensor_id}.defaultsTo({}, "first sensor log")
            ent:rumor_logs{sensor_id} := sensor_logs.put(message_id, rumor)

        }
    }

    rule recieved_gossip_seen {
        select when gossip seen
        pre {
            TX = subs:established().filter(function(v,k){v{"Rx"} == meta:eci}).head(){"Id"}
            //o_sensor_id = event:attrs{"sensorID"}
            body = event:attrs{"body"}
        }
        if body then noop()
        fired {
            ent:smart_tracker{TX} := body
        }
    }

    rule recieved_gossip_increment {
        select when gossip violation_rumor
        pre {
            rumor = event:attrs{"body"}
            sensor_id = rumor{"SensorID"}
            seq_num = rumor{"SeqNum"}
            increment = rumor{"Increment"}
        }
        if rumor then noop()
        fired {
            current_violation_rumors = ent:active_violations{sensor_id}.defaultsTo({}, "first violation log")
            ent:violations{sensor_id} := current_violation_rumors.put(seq_num, increment)
        }
    }

    rule recieved_gossip_thresh_seen {
        select when gossip violation_seen
        pre {
            TX = subs:established().filter(function(v,k){v{"Rx"} == meta:eci}).head(){"Id"}
            body = event:attrs{"body"}

        }
        if body then noop()
        fired {
            ent:violation_tracker{TX} := body
        }
    }

    // rule setup_subscription {
    //     select when wrangler inbound_pending_subscription_added
    //     if event:attrs{"name"} == "gossip_sub" then noop()
    //     fired {
    //         req_sensor_id = event:attrs{"req_sensor_id"}
    //         raise wrangler event "pending_subscription_approval" attributes event:attrs.put("res_sensor_id", ent:sensor_id);
    //     }
    // }

    // rule request_subscription {
    //     select when gossip setup_new_subscription
    //     pre {
    //         wellknownRx = event:attrs{"wellknownRx"}
    //         sensor_id = ent:sensor_id
    //     }
    //     always {
    //         raise wrangler event "subscription"
    //             attributes {
    //                 "name":"gossip_sub",
    //                 "channel_type":meta:rid,        
    //                 "wellKnown_Tx": wellknownRx,
    //                 "req_sensor_id": sensor_id,           
    //                 "Rx_role":"gossip_node",
    //                 "Tx_role":"gossip_node"
    //             }
    //     }
    // }

    // rule subscription_added {
    //     select when wrangler subscription_added
    //     pre {
    //         res_sensor_id = event:attrs{"res_sensor_id"}
    //     }
    //     if res_sensor_id then noop()
    //     fired {
    //         ent:sub_list := ent:sub_list.defaultsTo({}, "first Sub").put(res_sensor_id, event:attrs{"bus"})
    //     }
    // }

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

    rule clear_threshold_tracker {
        select when debug clear_threshold_tracker
        always {
            ent:violation_tracker := {}
        }
    }

    rule clear_seq_num {
        select when debug clear_seq_num 
        always {
            ent:seq_num := 0
        }
    }

    rule clear_active_violations {
        select when debug clear_active_violations
        always {
            ent:active_violations := {}
        }
    }
}