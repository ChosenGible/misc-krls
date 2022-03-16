ruleset sub_manager {
    meta {
        name "Manage Subscriptions"
        author "Alex Brown"

        use module io.picolabs.wrangler alias wrangler
    }
    rule autoAcceptSubscriptions {
        select when wrangler inbound_pending_subscription_added
        if event:attrs{"name"} == "parent_sub" then noop()
        fired {
            raise wrangler event "pending_subscription_approval" attributes event:attrs;
        }
    }
}