#!/usr/bin/env bash

args="$@"
expression="ellmer::chat_google_gemini('You are a friendly but terse assistant.', model = 'gemini-2.0-flash')\$chat('"$args"')"
rig run -r release -e "$expression"

