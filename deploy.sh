#!/bin/sh

rm -rf "${WOW_BETA_ADDON_DIR}tullaRange"
rm -rf "${WOW_BETA_ADDON_DIR}tullaRange_Config"

cp -r tullaRange "${WOW_BETA_ADDON_DIR}"
cp -r tullaRange_Config "${WOW_BETA_ADDON_DIR}"

cp LICENSE "${WOW_BETA_ADDON_DIR}tullaRange"
cp README  "${WOW_BETA_ADDON_DIR}tullaRange"