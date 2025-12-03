# SPDX-FileCopyrightText: None
# SPDX-License-Identifier: CC0-1.0
import Config

test_pmsg_path = Path.expand("test_pmsg")
File.exists?(test_pmsg_path) || File.touch!(test_pmsg_path)

config :ramoops_logger,
  pmsg_path: test_pmsg_path
