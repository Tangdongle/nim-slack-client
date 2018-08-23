# Package

version       = "0.1.0"
author        = "Ryanc_signiq"
description   = "API Wrapper for Slack"
license       = "GPLv3"
srcDir        = "src"

# Dependencies

requires "nim >= 0.18.0"
requires "websocket#head"
requires "nimobserver"

task tests, "Run Project Tests":
    exec("mkdir -p tests/bin")
    exec("for i in ./tests/*.nim; do fname=$(basename \"$i\"); echo $fname; nim c -r --threads:on -d:ssl --out:tests/bin/$fname tests/$fname; done")

task run, "Run the main file":
    exec("mkdir -p bin")
    exec("nim c -r -d:ssl --threads:on --out:bin/slackapi src/slackapi.nim")

task run_shared, "Run the shared file tests":
    exec("mkdir -p bin")
    exec("nim c -r -d:ssl --threads:on --out:bin/shared src/slack/shared.nim")

task check_files, "Check all files":
    exec("for i in src/**/*.nim; do nim check $i; done")
