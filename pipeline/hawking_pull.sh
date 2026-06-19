#!/bin/env sh
echo "Getting Auth Token"
./get_auth.sh
echo "Pulling stats from Hawking"
curl --silent -H @auth_token.curl -d @stats.gql "https://hawkingapi.camelotunchained.com/graphql" | tee stats.json |  jq -r '"Received \(.data.game.stats | length) Formulae"'
