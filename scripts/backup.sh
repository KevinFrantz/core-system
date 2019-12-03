#!/bin/bash
# Executes all scripts which are necessary to backup data
# @author Kevin Veen-Birkenbach [aka. Frantz]
source "$(dirname "$(readlink -f "${0}")")/base.sh"
bash "$SCRIPT_PATH/import-data-from-system.sh"
bash "$SCRIPT_PATH/push-local-repositories.sh"
