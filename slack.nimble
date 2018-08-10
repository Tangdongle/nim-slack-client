# Package

version       = "0.1.0"
author        = "Ryanc_signiq"
description   = "Wrapper for Slack"
license       = "GPLv3"
srcDir        = "src"

# Dependencies

requires "nim >= 0.18.0"
requires "websocket#head"

task tests, "Run Project Tests":
    exec("mkdir -p tests/bin")
    exec("for i in ./tests/*.nim; do fname=$(basename \"$i\"); echo $fname; nim c -r -d:ssl --out:tests/bin/$fname tests/$fname; done")

task run, "Run the main file":
    exec("mkdir -p bin")
    exec("nim c -r -d:ssl --out:bin/slack src/slack.nim")

task run_shared, "Run the shared file tests":
    exec("mkdir -p bin")
    exec("nim c -r -d:ssl --out:bin/shared src/slack/shared.nim")
