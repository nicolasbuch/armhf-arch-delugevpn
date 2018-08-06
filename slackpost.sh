#!/bin/bash

# Usage: slackpost "<message>"
#
# Please declare environment variables:
#   - APP_SLACK_WEBHOOK
#   - APP_SLACK_CHANNEL

text=$1

if [[ "${APP_SLACK_WEBHOOK}" == "" ]]
then
        echo "No webhook_url specified"
        echo "Please set APP_SLACK_WEBHOOK variable"
        exit 1
fi

if [[ "${APP_SLACK_CHANNEL}" == "" ]]
then
        APP_SLACK_CHANNEL=general
fi

if [[ $text == "" ]]
then
        echo "No text specified"
        exit 1
fi

escapedText=$(echo $text | sed 's/"/\"/g' | sed "s/'/\'/g" )
json="{\"channel\": \"$APP_SLACK_CHANNEL\", \"text\": \"$escapedText\"}"

curl -s -d "payload=$json" "$APP_SLACK_WEBHOOK"