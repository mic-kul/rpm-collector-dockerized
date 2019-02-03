#!/usr/bin/env bash

docker-compose up -d

echo "Grafana: http://127.0.0.1:3000 - user: admin password: admin"

echo
echo "Create a new database collector\n"
echo "${curl -XPOST 'http://localhost:8086/query' --data-urlencode 'q=CREATE DATABASE collector'}"
