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

        /*
        Smart Tracker schema:
        {
            {<SID>:
                {<OSID>:<SeqNum>},
                ...
            }
        }
        */
        smart_tracker = function(){
            ent:smart_tracker
        }

        /*
        Rumor schema:
        {
            {<SID>:[<Message>, ...]},
            ...
        } 
        */
        recorded_rumors = function(){
            ent:rumor_logs
        }

        get_next_seq_num = function(sub, other_sub_id){
            sub_logs = ent:rumor_logs{sub}
            get_next_seq_num_rec(sub_logs, other_sub_id, 0)
        }

        get_next_seq_num_rec = function(sub_logs, other_sub_id, check_num){
            check_num >< ent:sub_logs.filter(function(v, k){ v{"SensorID"} == other_sub_id }) => get_next_seq_num_rec(sub_logs, other_sub_id, check_num + 1) | check_num
        }

        get_peer = function(){
            noop()
        }

        /* 
        syntax of message returned by prepare_message:
        {
            type: <rumor | seen>
            body: { depends on which type is used }
        }

        attrs for rumor:
        {
            "MessageID" : {<MID>:<SeqNum>},
            "SensorID" : <SID>,
            "Temperature" : <Temp>,
            "Timestamp" : <Timestamp>
        }

        attrs for seen:
        {
            <ID>:<SeqNum>
            ...
        }
        
        */

        prepare_rumor = function(sub){
            noop()
        }

        prepare_seen = function(sub){
            noop()
        }

        prepare_message = function(sub){
            random:integer(upper = 1, lower = 0) == 1 => prepare_rumor(sub) | prepare_seen(sub)
        }

        send_message = defaction(sub, message){
            sub_id = ent:sub_list{[sub, "bus", "Id"]}
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

        add_rumor_to_log = defaction(sub_id, message){
            new_rumor_logs = sub_id >< ent:rumor_logs => ent:rumor_logs{sub_id}.append(message) | ent:rumor_logs.put(sub_id, [].append(message))
            ent:rumor_logs := new_rumor_logs
        }

        update = defaction(sub, message){
            noop()
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

    rule self_temp_log_report {
        select when wovyn new_temperature_reading
        pre {
            temp = event:attrs{"temperature"}
            time = event:attrs{"timestamp"}
            origin_id = random:uuid()
            self_seq_num = ent:seq_num.defaultsTo(no_message_num, "first log")
            self_sensor_id = ent:sensor_id
            message_id = {}.put(self_sensor_id, self_seq_num)

        }
        if temp && time then add_rumor_to_log(self_sensor_id, {
            "MessageID" : message_id,
            "SensorID" : self_sensor_id,
            "Temperature" : temp,
            "Timestamp" : time
        })
        fired {
            ent:seq_num := self_seq_num + 1
        }
    }

    rule initialize_ruleset {
        select when wrangler ruleset_installed where event:attr("rids") >< meta:rid
        always {
            ent:sensor_id := random:uuid()
            ent:rumor_logs := {}
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

    rule recieved_gossip_rumor {
        select when gossip rumor
    }

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
}