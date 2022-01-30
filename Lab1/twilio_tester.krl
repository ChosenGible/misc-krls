ruleset twilio_tester {
    meta {
        name "Twilio Tester"
        author "Alex Brown"

        use module twilio_wrapper alias twilio
            with
                sid = meta:rulesetConfig{"sid"}
                token = meta:rulesetConfig{"token"}

        shares messages
    }

    global {
        messages = function(from, to, pageSize){
            twilio:messages(from, to, pageSize)
        }
    }

    rule send_sms {
        select when twilio new_message
        pre {
            message = event:attrs{"message"}
            fromPhone = event:attrs{"from"}
            toPhone = event:attrs{"to"}
        }
        twilio:sendSMS(fromPhone, toPhone, message)
    }
}