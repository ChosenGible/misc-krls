ruleset sensor_profile {
    meta {
        name "Sensor Profile"
        author "Alex Brown"

        shares sensor_name, sensor_location, sensor_threshold
        provides sensor_name, sensor_location, sensor_threshold
    }

    global {
        clearName = "Not Set"
        clearLocation = "Not Set"
        clearThreshold = "0"

        sensor_name = function(){
            ent:sensorName
        }
        sensor_location = function(){
            ent:sensorLocation
        }
        sensor_threshold = function(){
            ent:threshold
        }
    }

    rule sensor_update {
        select when sensor profile_updated

        pre {
            sensorName = event:attrs{"sensorName"}
            sensorLocation = event:attrs{"sensorLocation"}
            threshold = event:attrs{"threshold"}
        }
        send_directive("sensor_profile", {"new name":sensorName, "new location":sensorLocation, "new threshold":threshold})
        always{
            ent:sensorName := sensorName => sensorName | ent:sensorName.defaultsTo(clearName, "Name not initialized");
            ent:sensorLocation := sensorLocation => sensorLocation | ent:sensorLocation.defaultsTo(clearLocation, "Location not initialized");
            ent:threshold := threshold => threshold | ent:threshold.defaultsTo(clearThreshold, "Threshold not initialized");
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