ruleset hello_world {
    meta {
      name "Hello World"
      description <<
  A first ruleset for the Quickstart
  >>
      author "Phil Windley"
      shares hello
    }
     
    global {
      hello = function(obj) {
        msg = "Hello " + obj;
        msg
      }

    }
     
    rule hello_world {
      select when echo hello
      send_directive("say", {"something": "Hello World"})
    }  
    
    rule hello_monkey {
      select when echo monkey
      //send_directive("say", {"something" : "Hello " + (event:attrs{"name"} || "Monkey")})
      send_directive("say", {"something" : event:attrs{"name"} => ("Hello " + event:attrs{"name"}) | "Hello Monkey"})
    }
  }