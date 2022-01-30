ruleset twilio_wrapper {
    meta {
        name "Twilio Wrapper"
        author "Alex Brown"

        configure using
            sid = ""
            token = ""

        provides messages, sendSMS
    }

    global {
        base_uri = "https://api.twilio.com/2010-04-01/Accounts/" + sid
        api_auth = {
                "username":sid,
                "password":token
            }

        messages = function(fromPhone, toPhone, ItemPerPage){
            map1 = toPhone => {}.put("To", toPhone) | {}
            map2 = fromPhone => map1.put("From", fromPhone) | map1
            queryString = ItemPerPage => map2.put("PageSize", ItemPerPage) | map2
            response = http:get(base_uri + "/Messages.json", qs=queryString, auth=api_auth)
            response{"content"}.decode()
        }

        sendSMS = defaction(fromPhone, toPhone, message) {
            formData = {
                    "From": fromPhone,
                    "To": toPhone,
                    "Body": message
                }
            http:post(base_uri + "/Messages", form=formData, auth=api_auth) setting(response)
            return response.klog("ORANGE")
        }
    }

}