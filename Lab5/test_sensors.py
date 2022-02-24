import json
import urllib3

EVENT_URL = "http://localhost:3000/sky/event/ckzzyxgpw001me1ztf5ta2up2/0001/"
QUERY_URL = "http://localhost:3000/sky/cloud/ckzzyxgpw001me1ztf5ta2up2/manage_sensors/"

def queryToString(query, params = ""):
    http = urllib3.PoolManager()
    url = QUERY_URL + query + params
    response = http.request("GET", url).data.decode('utf8')
    return response

def eventToString(domain, e_type, attrs = None):
    http = urllib3.PoolManager()
    url = ""
    if bool(attrs):
        url = EVENT_URL + domain + "/" + e_type + "?" + attrs
    else:
        url = EVENT_URL + domain + "/" + e_type
    response = http.request("GET", url).data.decode('utf8')
    return response


def checkSensorNames(sensor_map):
    print("Sensor Names")
    for key in sensor_map:
        print(key + ": " + queryToString("sp_sensor_name", "?sensor_id=" + key))

def checkSensorLocations(sensor_map):
    print("Sensor Locations")
    for key in sensor_map:
        print(key + ": " + queryToString("sp_sensor_location", "?sensor_id=" + key))

def checkSensorThreshold(sensor_map):
    print("Sensor Thresholds")
    for key in sensor_map:
        print(key + ": " + queryToString("sp_sensor_threshold", "?sensor_id=" + key))

def checkSensorPhone(sensor_map):
    print("Alert Phones")
    for key in sensor_map:
        print(key + ": " + queryToString("sp_alert_phone", "?sensor_id=" + key))

def checkTempertures():
    print("Temperatures")
    print(queryToString("temperatures"))

def getSensorMap():
    return json.loads(queryToString("sensors"))

def addSensorPico():
    print("ADDING SENSOR")
    directive = eventToString("sensor", "new_sensor", "sensor_id=test")
    print(directive)

def removeSensorPico():
    print("REMOVING SENSOR")
    directive = eventToString("sensor", "unneeded_sensor", "sensor_id=test")
    print(directive)

sensor_map = getSensorMap()
print("Sensors")
print(sensor_map)
addSensorPico()
sensor_map = getSensorMap()
print("Sensor after add")
print(sensor_map)
removeSensorPico()
sensor_map = getSensorMap()

checkSensorNames(sensor_map)
checkSensorLocations(sensor_map)
checkSensorThreshold(sensor_map)
checkSensorPhone(sensor_map)

print("Sensors after remove")
print(sensor_map)

checkTempertures()
