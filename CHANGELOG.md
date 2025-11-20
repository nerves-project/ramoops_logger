<!--
  SPDX-FileCopyrightText: None
  SPDX-License-Identifier: CC0-1.0
-->

# Changelog

## v0.3.1

* Changes
  * Add missing `:gen_event` behaviour callbacks to ignore a `handle_info/2`
    call from the logger.

## v0.3.0

Renamed `OopsLogger` to `RamoopsLogger`

* Enhancements
  * Docs, types, and test clean up
  * Support recovered log path configuration
  * Support for configured pmsg path

## v0.2.0

* Enhancements
  * Added `OopsLogger.available_log?/0` function to check if there is a ramoops log

## v0.1.0

Initial Release
