#!/usr/bin/env bash
make clean_all --file=../OpenROAD-flow-scripts/flow/Makefile DESIGN_CONFIG=config.mk
make --file=../OpenROAD-flow-scripts/flow/Makefile DESIGN_CONFIG=config.mk