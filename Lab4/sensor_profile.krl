ruleset sensor_profile {
    meta {
        name "Sensor Profile"
        author "Alex Brown"

        shares sensor_name, sensor_location, sensor_threshold, alert_phone
        provides sensor_name, sensor_location, sensor_threshold, alert_phone
    }

    global {
        clearName = "Not Set"
        clearLocation = "Not Set"
        clearThreshold = "0"
        clearPhone = "+19199997000"

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
        }
    }
}