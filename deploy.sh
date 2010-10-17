#!/bin/sh

rm -rf "${WOW_ADDON_DIR}tullaRange"
rm -rf "${WOW_ADDON_DIR}tullaRange_Config"

cp -r tullaRange "${WOW_ADDON_DIR}"
cp -r tullaRange_Config "${WOW_ADDON_DIR}"

cp LICENSE "${WOW_ADDON_DIR}tullaRange"
cp README.textile  "${WOW_ADDON_DIR}tullaRange"