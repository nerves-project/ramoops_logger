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
    # Start fresh each time
    _ = File.rm(@test_pmsg_file)
    _ = File.rm(@test_recovered_path)
    File.touch!(@test_pmsg_file)

    # Attach the RamoopsLogger handler with the test path
    RamoopsLogger.attach(
      pmsg_path: @test_pmsg_file,
      recovered_log_path: @test_recovered_path
    )

    on_exit(fn ->
      RamoopsLogger.detach()
      _ = File.rm(@test_pmsg_file)
      _ = File.rm(@test_recovered_path)
    end)

    :ok
  end

  test "logs a message" do
    Logger.debug("hello")
    Process.sleep(100)

    assert File.exists?(@test_pmsg_file)
    contents = File.read!(@test_pmsg_file)
    assert contents =~ "debug"
    assert contents =~ "hello"
  end

  test "logs multiple messages" do
    Logger.info("first message")
    Logger.warning("second message")
    Logger.error("third message")
    Process.sleep(100)

    assert File.exists?(@test_pmsg_file)
    contents = File.read!(@test_pmsg_file)
    assert contents =~ "first message"
    assert contents =~ "second message"
    assert contents =~ "third message"
  end

  test "provides a reasonable error message for bad pmsg path" do
    RamoopsLogger.detach()

    {:error, {:handler_not_added, reason}} =
      RamoopsLogger.attach(pmsg_path: "/dev/does/not/exist")

    assert is_binary(reason)
    assert reason =~ "Unable to open"
    assert reason =~ "/dev/does/not/exist"
  end

  test "recovered log helpers" do
    assert RamoopsLogger.recovered_log_path() == @test_recovered_path

    refute RamoopsLogger.available_log?()

    File.write!(@test_recovered_path, "test test test")

    assert RamoopsLogger.available_log?()
    assert {:ok, "test test test"} == RamoopsLogger.read()
  end

  test "dump function displays log contents" do
    File.write!(@test_recovered_path, "crash log content")

    import ExUnit.CaptureIO

    output = capture_io(fn -> RamoopsLogger.dump() end)
    assert output == "crash log content"
  end

  test "attach/detach is idempotent" do
    # Already attached in setup
    assert :ok = RamoopsLogger.attach()
    assert :ok = RamoopsLogger.detach()
    assert :ok = RamoopsLogger.detach()
  end
end
