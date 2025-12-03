# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule RamoopsLogger.PmsgWriterTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  @test_dir "__test_pmsg_writer"

  setup do
    _ = File.rm_rf!(@test_dir)
    File.mkdir_p!(@test_dir)

    on_exit(fn ->
      _ = File.rm_rf!(@test_dir)
    end)

    :ok
  end

  test "application handles gracefully when pmsg device doesn't exist" do
    Application.stop(:ramoops_logger)

    non_existent_path = Path.join(@test_dir, "non_existent_pmsg")
    Application.put_env(:ramoops_logger, :pmsg_path, non_existent_path)

    logs =
      capture_log(fn ->
        Application.start(:ramoops_logger)
        # Give it time to process
        Process.sleep(100)
      end)

    assert logs =~ "Failed to add ramoops_logger log handler"
  end
end
