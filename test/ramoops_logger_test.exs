# SPDX-FileCopyrightText: 2019 SmartRent
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule RamoopsLoggerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  require Logger

  @test_dir "__test"
  @test_pmsg_file Path.join(@test_dir, "dev_pmsg")
  @test_pstore_mount_point Path.join(@test_dir, "sys_fs_pstore")

  setup do
    # Start fresh each time
    Application.stop(:ramoops_logger)
    _ = File.rm_rf!(@test_dir)
    File.mkdir_p!(@test_pstore_mount_point)
    File.touch!(@test_pmsg_file)

    # Start the RamoopsLogger with the test path
    Application.put_env(:ramoops_logger, :pmsg_path, @test_pmsg_file)
    Application.put_env(:ramoops_logger, :pstore_mount_point, @test_pstore_mount_point)
    Application.put_env(:ramoops_logger, :auto_mount?, false)

    Application.start(:ramoops_logger)

    on_exit(fn ->
      _ = File.rm_rf!(@test_dir)
    end)

    :ok
  end

  test "logs error messages" do
    Logger.debug("debug message")
    Logger.error("error message")
    Process.sleep(100)

    assert File.exists?(@test_pmsg_file)
    contents = File.read!(@test_pmsg_file)

    # "unknown" is the application name that gets logged
    assert contents =~ "unknown error message"
    refute contents =~ "debug"
  end

  test "logs error when used as an Elixir backend" do
    logs = capture_log(fn -> RamoopsLogger.init(:anything) end)
    assert logs =~ "RamoopsLogger is no longer an Elixir Logger backend"
  end

  test "recovered log helpers" do
    recovered_path = Path.join(@test_pstore_mount_point, "pmsg-ramoops-0")
    assert RamoopsLogger.recovered_log_path() == recovered_path

    refute RamoopsLogger.available_log?()

    File.write!(recovered_path, "test test test")

    assert RamoopsLogger.available_log?()
    assert {:ok, "test test test"} == RamoopsLogger.read()
  end
end
