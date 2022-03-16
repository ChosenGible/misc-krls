ruleset manager_profile {
    meta {
        name "Manager Profile"
        author "Alex Brown"

        configure using
            sid = ""
            token = ""

        shares alert_phone, messages
        provides alert_phone, messages, sendSMS
    }
    global {
        clearPhone = "+19199997000"
        fromPhone = "+17655655074"

        base_uri = "https://api.twilio.com/2010-04-01/Accounts/" + sid
        api_auth = {
            "username":sid,
            "password":token
        }

        alert_phone = function(){
            ent:phone
        }

        messages = function(ItemPerPage){
            map1 = ent:toPhone => {}.put("To", ent:toPhone) | {}
            map2 = fromPhone => map1.put("From", fromPhone) | map1
            queryString = ItemPerPage => map2.put("PageSize", ItemPerPage) | map2
            response = http:get(base_uri + "/Messages.json", qs=queryString, auth=api_auth)
            response{"content"}.decode()
        }
        
        sendSMS = defaction(message) {
            formData = {
                    "From": fromPhone,
                    "To": ent:phone,
                    "Body": message
                }
            http:post(base_uri + "/Messages", form=formData, auth=api_auth) setting(response)
            return response.klog("ORANGE")
        }
    }

    rule update_alert_phone {
        select when sensor update_alert_phone
        pre {
            newPhone = event:attrs{"phone"}
        }
        if newPhone then noop()
        fired {
            ent:phone := newPhone
        }
    }

    rule reset_phone {
        select when sensor reset_alert_phone
        always {
            ent:phone := clearPhone
        }
    }


    
}