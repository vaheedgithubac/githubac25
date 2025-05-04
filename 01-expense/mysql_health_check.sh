#!/bin/env bash

mysql -h localhost -u root -p${MYSQL_ROOT_PASSWORD} -e "SELECT 1"
