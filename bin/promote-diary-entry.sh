#!/bin/bash
# promote diary entry v0.1
# 20220811 luciano
# this "promotes" a single diary entry by resetting dates on record to current timestamp UTC
psql -d ogfdevapi -c "set timezone to 'utc';update diary_entries set created_at = current_timestamp, updated_at = current_timestamp, visible = 't' where id = 3245"
