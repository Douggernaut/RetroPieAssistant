#!/bin/bash

SCRIPT_DIR="${0%/*}"

$SCRIPT_DIR/change_configs.sh
$SCRIPT_DIR/generate_uae.sh -q
