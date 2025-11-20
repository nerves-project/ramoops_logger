# SPDX-FileCopyrightText: 2019 SmartRent
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule RamoopsLoggerTest do
  use ExUnit.Case, async: false

  require Logger

  @test_pmsg_file "__test_pmsg"
  @test_recovered_path "__recovered_pmsg"

  setup do
    Logger.remove_backend(:console)

    # Start fresh each time
    _ = File.rm(@test_pmsg_file)
    _ = File.rm(@test_recovered_path)
    File.touch!(@test_pmsg_file)

    # Start the RamoopsLogger with the test path
    Application.put_env(:logger, RamoopsLogger,
      pmsg_path: @test_pmsg_file,
      recovered_log_path: @test_recovered_path
    )

    Logger.add_backend(RamoopsLogger, flush: true)

    on_exit(fn ->
      Logger.remove_backend(RamoopsLogger)
      _ = File.rm(@test_pmsg_file)
      _ = File.rm(@test_recovered_path)
    end)

    :ok
  end

  test "logs a message" do
    Logger.debug("hello")
    Logger.flush()
    Process.sleep(100)

    assert File.exists?(@test_pmsg_file)
    contents = File.read!(@test_pmsg_file)
    assert contents =~ "[debug] hello"
  end

  test "changing configuration" do
    new_path = @test_pmsg_file <> ".new"
    _ = File.rm(new_path)

    Logger.configure_backend(RamoopsLogger, pmsg_path: new_path)
    Logger.info("changing configuration")
    Logger.flush()
    Process.sleep(100)

    contents = File.read!(new_path)
    assert contents =~ "changing configuration"

    File.rm!(new_path)
  end

  test "provides a reasonable error message for bad pmsg path" do
    Logger.remove_backend(RamoopsLogger)
    Application.put_env(:logger, RamoopsLogger, pmsg_path: "/dev/does/not/exist")

    {:error, {reason, _stuff}} = Logger.add_backend(RamoopsLogger)
    assert reason == "Unable to open '/dev/does/not/exist' (:enoent). RamoopsLogger won't work."
  end

  test "recovered log helpers" do
    assert RamoopsLogger.recovered_log_path() == @test_recovered_path

    refute RamoopsLogger.available_log?()

    File.write!(@test_recovered_path, "test test test")

    assert RamoopsLogger.available_log?()
    assert {:ok, "test test test"} == RamoopsLogger.read()
  end
end
