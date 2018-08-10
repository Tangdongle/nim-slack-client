import src/slack/shared
import unittest, json

suite "Slack Parsing Tests":
    echo "Testing message parsing"

    setup: 
        let test_response = %* 
            {
            "ok":true,
            "url":"wss://cerberus-xxxx.lb.slack-msgs.com/websocket/mnloLq2xBucQDkvlyrxAdll2uQ6jTZuX-qfhAi0_uvCXFTET6ZviTP5b-tOJAkw1N-Ynsfp7ZB4J6nYKQHgCDx4kvjfd6eUHiMp_t6-PwQU=",
            "team": {
                "id":"G05LKG9QZ",
                "name":"Slacktest",
                "domain":"slacktest"
                },
            "self": {
                "id":"V66KSKAL10",
                "name":"slackbot"
                }
            }

    test "Parse User Data":
        let user = parseUserData(test_response)

        check(user.id == "V66KSKAL10")
        check(user.name == "slackbot")
