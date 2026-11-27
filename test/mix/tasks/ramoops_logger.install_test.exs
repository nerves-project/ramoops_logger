# SPDX-FileCopyrightText: 2026 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.RamoopsLogger.InstallTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  alias Igniter.Project.Config

  @all_options [
    "--pmsg-path",
    "/dev/pmsg1",
    "--pstore-mount-point",
    "/tmp/pstore",
    "--pmsg-log",
    "pmsg-ramoops-1",
    "--no-pstore-auto-mount"
  ]

  defp nerves_project(files \\ %{}) do
    test_project(
      files:
        Map.merge(
          %{
            "config/config.exs" => """
            import Config

            config :logger, backends: [RingLogger]

            if Mix.target() == :host do
              import_config "host.exs"
            else
              import_config "target.exs"
            end
            """,
            "config/host.exs" => "import Config\n",
            "config/target.exs" => """
            import Config

            config :logger, RingLogger, max_size: 1024
            """
          },
          files
        )
    )
  end

  defp install(igniter, argv \\ []) do
    Igniter.compose_task(igniter, "ramoops_logger.install", argv)
  end

  describe "defaults" do
    test "write nothing to a Nerves project and explain the kernel requirement" do
      nerves_project()
      |> install()
      |> assert_unchanged()
      |> assert_has_notice(&(&1 =~ "CONFIG_PSTORE_PMSG"))
      |> assert_has_notice(&(&1 =~ "RamoopsLogger.dump()"))
    end

    test "write nothing to a plain project" do
      igniter = test_project() |> install()

      assert_unchanged(igniter)
      assert_has_notice(igniter, &(&1 =~ "/dev/pmsg0"))
      refute Igniter.exists?(igniter, "config/config.exs")
      refute Igniter.exists?(igniter, "config/target.exs")
    end
  end

  describe "options" do
    test "go in config/target.exs in a Nerves project" do
      igniter = nerves_project() |> install(@all_options)

      assert_unchanged(igniter, ["config/config.exs", "config/host.exs"])
      refute Enum.any?(igniter.notices, &(&1 =~ "No config/target.exs"))

      igniter = apply_igniter!(igniter)

      assert file_content(igniter, "config/target.exs") == """
             import Config

             config :ramoops_logger,
               pmsg_path: "/dev/pmsg1",
               pstore_mount_point: "/tmp/pstore",
               pmsg_log: "pmsg-ramoops-1",
               auto_mount?: false

             config :logger, RingLogger, max_size: 1024
             """
    end

    test "fall back to config/config.exs with a notice in a plain project" do
      igniter = test_project() |> install(@all_options)

      assert_has_notice(igniter, &(&1 =~ "No config/target.exs"))
      refute Igniter.exists?(igniter, "config/target.exs")

      igniter = apply_igniter!(igniter)

      assert file_content(igniter, "config/config.exs") == """
             import Config

             config :ramoops_logger,
               pmsg_path: "/dev/pmsg1",
               pstore_mount_point: "/tmp/pstore",
               pmsg_log: "pmsg-ramoops-1",
               auto_mount?: false
             """
    end

    test "are written one at a time" do
      for {argv, expected} <- [
            {["--pmsg-path", "/dev/pmsg1"], ~s(config :ramoops_logger, pmsg_path: "/dev/pmsg1")},
            {["--pstore-mount-point", "/tmp/pstore"],
             ~s(config :ramoops_logger, pstore_mount_point: "/tmp/pstore")},
            {["--pmsg-log", "pmsg-ramoops-1"],
             ~s(config :ramoops_logger, pmsg_log: "pmsg-ramoops-1")},
            {["--no-pstore-auto-mount"], "config :ramoops_logger, auto_mount?: false"},
            {["--pstore-auto-mount"], "config :ramoops_logger, auto_mount?: true"}
          ] do
        igniter = nerves_project() |> install(argv) |> apply_igniter!()

        assert file_content(igniter, "config/target.exs") == """
               import Config

               #{expected}
               config :logger, RingLogger, max_size: 1024
               """
      end
    end

    test "never overwrite existing ramoops_logger config" do
      target = """
      import Config

      config :ramoops_logger,
        pmsg_path: "/dev/my_pmsg",
        auto_mount?: true
      """

      igniter =
        nerves_project(%{"config/target.exs" => target})
        |> install(["--pmsg-path", "/dev/pmsg1", "--no-pstore-auto-mount"])

      assert_unchanged(igniter)

      igniter =
        nerves_project(%{"config/target.exs" => target})
        |> install(@all_options)
        |> apply_igniter!()

      assert file_content(igniter, "config/target.exs") == """
             import Config

             config :ramoops_logger,
               pmsg_path: "/dev/my_pmsg",
               auto_mount?: true,
               pstore_mount_point: "/tmp/pstore",
               pmsg_log: "pmsg-ramoops-1"
             """
    end
  end

  describe "idempotency" do
    test "second run with defaults changes nothing" do
      nerves_project()
      |> install()
      |> apply_igniter!()
      |> install()
      |> assert_unchanged()
    end

    test "second run with options changes nothing" do
      nerves_project()
      |> install(@all_options)
      |> apply_igniter!()
      |> install(@all_options)
      |> assert_unchanged()
    end

    test "second run in a plain project changes nothing" do
      test_project()
      |> install(@all_options)
      |> apply_igniter!()
      |> install(@all_options)
      |> assert_unchanged()
    end

    test "second run after removing the legacy backend changes nothing" do
      nerves_project(%{
        "config/config.exs" => "import Config\n\nconfig :logger, backends: [RamoopsLogger]\n"
      })
      |> install()
      |> apply_igniter!()
      |> install()
      |> assert_unchanged()
    end
  end

  describe "existing logger config" do
    # ring_logger.install and ramoops_logger.install usually run in the same
    # project. RamoopsLogger is an Erlang logger handler added by its
    # application, so this installer must leave `config :logger` to the others
    # no matter which one runs first.
    test "RingLogger installed first: its backend and options are untouched" do
      nerves_project()
      |> install(@all_options)
      |> assert_unchanged(["config/config.exs", "config/host.exs"])
      |> apply_igniter!()
      |> then(fn igniter ->
        assert file_content(igniter, "config/target.exs") =~
                 "config :logger, RingLogger, max_size: 1024\n"
      end)
    end

    test "RamoopsLogger installed first: no logger config is left for others to trip on" do
      files = %{
        "config/config.exs" => """
        import Config

        if Mix.target() == :host do
          import_config "host.exs"
        else
          import_config "target.exs"
        end
        """,
        "config/target.exs" => "import Config\n"
      }

      igniter = nerves_project(files) |> install(@all_options) |> apply_igniter!()

      for file <- ["config/config.exs", "config/host.exs", "config/target.exs"] do
        refute file_content(igniter, file) =~ "config :logger"
        refute file_content(igniter, file) =~ "RamoopsLogger"
      end
    end

    # What ring_logger.install writes today: a `LoggerBackends.add/1` call in
    # config/runtime.exs and the console handler turned off in target.exs.
    @ring_logger_runtime """
    import Config

    Application.ensure_all_started(:logger_backends)
    LoggerBackends.add(RingLogger)
    """

    test "after ring_logger.install: its runtime.exs and target.exs lines are kept" do
      files = %{
        "config/runtime.exs" => @ring_logger_runtime,
        "config/target.exs" => """
        import Config

        config :logger, default_handler: false
        """
      }

      nerves_project(files) |> install() |> assert_unchanged()

      igniter = nerves_project(files) |> install(@all_options)

      assert_unchanged(igniter, ["config/config.exs", "config/host.exs", "config/runtime.exs"])

      igniter = apply_igniter!(igniter)

      assert file_content(igniter, "config/target.exs") == """
             import Config

             config :ramoops_logger,
               pmsg_path: "/dev/pmsg1",
               pstore_mount_point: "/tmp/pstore",
               pmsg_log: "pmsg-ramoops-1",
               auto_mount?: false

             config :logger, default_handler: false
             """
    end

    test "before ring_logger.install: its changes apply cleanly on top" do
      # Same calls as ring_logger.install makes. It can't be composed here
      # since ring_logger isn't a dependency of this library.
      igniter =
        nerves_project(%{"config/target.exs" => "import Config\n"})
        |> install(@all_options)
        |> apply_igniter!()
        |> Config.configure_new("target.exs", :logger, [:default_handler], false)
        |> Igniter.create_new_file("config/runtime.exs", @ring_logger_runtime)
        |> apply_igniter!()

      assert file_content(igniter, "config/target.exs") == """
             import Config

             config :logger, default_handler: false

             config :ramoops_logger,
               pmsg_path: "/dev/pmsg1",
               pstore_mount_point: "/tmp/pstore",
               pmsg_log: "pmsg-ramoops-1",
               auto_mount?: false
             """

      assert file_content(igniter, "config/runtime.exs") == @ring_logger_runtime

      # ...and a rerun of this installer leaves all of it alone
      igniter |> install(@all_options) |> assert_unchanged()
    end

    test "other handlers, backends and logger options are untouched" do
      config = """
      import Config

      config :logger, level: :debug, backends: [:console, RingLogger, MyApp.Backend]
      config :logger, :default_handler, level: :info
      config :logger, RingLogger, max_size: 2048
      config :logger_backends, backends: [RingLogger]
      """

      nerves_project(%{"config/config.exs" => config})
      |> install()
      |> assert_unchanged()
    end
  end

  describe "legacy backend entry" do
    test "is removed without touching the other backends" do
      igniter =
        nerves_project(%{
          "config/config.exs" => """
          import Config

          config :logger, level: :debug, backends: [RamoopsLogger, RingLogger, :console]
          config :logger, RingLogger, max_size: 2048
          """
        })
        |> install()

      assert_unchanged(igniter, ["config/target.exs", "config/host.exs"])

      igniter = apply_igniter!(igniter)

      assert file_content(igniter, "config/config.exs") == """
             import Config

             config :logger, level: :debug, backends: [RingLogger, :console]
             config :logger, RingLogger, max_size: 2048
             """
    end

    test "is removed from the 3-arity form and from any position" do
      igniter =
        nerves_project(%{
          "config/config.exs" => """
          import Config

          config :logger, :backends, [RingLogger, RamoopsLogger]
          """
        })
        |> install()
        |> apply_igniter!()

      assert file_content(igniter, "config/config.exs") == """
             import Config

             config :logger, :backends, [RingLogger]
             """
    end

    test "is removed from config/target.exs" do
      igniter =
        nerves_project(%{
          "config/target.exs" => """
          import Config

          config :logger, backends: [RingLogger, RamoopsLogger]
          """
        })
        |> install()

      assert_unchanged(igniter, ["config/config.exs", "config/host.exs"])

      igniter = apply_igniter!(igniter)

      assert file_content(igniter, "config/target.exs") == """
             import Config

             config :logger, backends: [RingLogger]
             """
    end

    test "leaves a backends value that isn't a literal list alone" do
      nerves_project(%{
        "config/config.exs" => """
        import Config

        backends = [RingLogger, RamoopsLogger]
        config :logger, backends: backends
        """
      })
      |> install()
      |> assert_unchanged()
    end
  end

  defp file_content(igniter, path) do
    igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)
  end
end
