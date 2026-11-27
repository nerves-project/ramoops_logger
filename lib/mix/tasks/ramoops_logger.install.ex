# SPDX-FileCopyrightText: 2026 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.RamoopsLogger.Install.Docs do
  @moduledoc false

  @spec short_doc() :: String.t()
  def short_doc() do
    "Installs ramoops_logger in your Nerves project."
  end

  @spec example() :: String.t()
  def example() do
    "mix igniter.install ramoops_logger"
  end

  @spec long_doc() :: String.t()
  def long_doc() do
    """
    #{short_doc()}

    RamoopsLogger registers its Erlang logger handler when the
    `:ramoops_logger` application starts, so no `config :logger` changes are
    needed and none are made. The defaults work on most official Nerves
    systems, so by default this installer writes no configuration at all.

    What it does:

    * Removes `RamoopsLogger` from any `config :logger, backends: [...]` list.
      That was how RamoopsLogger v0.3 and earlier were set up and it no longer
      works. Other backends in the list are left alone.
    * Writes `config :ramoops_logger, ...` for the options below, but only for
      the ones passed. They go in `config/target.exs` when it exists and
      `config/config.exs` otherwise. Existing values are never overwritten.
    * Prints a reminder that the Nerves system's Linux kernel needs `pstore`
      support. The installer cannot check or change that.

    ## Example

    ```bash
    #{example()}
    ```

    ## Options

    * `--pmsg-path` - Path to the pmsg device. Library default: `/dev/pmsg0`
    * `--pstore-mount-point` - Where pstore is mounted. Library default: `/sys/fs/pstore`
    * `--pmsg-log` - Name of the recovered log file in the pstore mount.
      Library default: `pmsg-ramoops-0`
    * `--no-pstore-auto-mount` - Don't mount pstore automatically when reading
      the recovered log. Library default is to mount it.
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.RamoopsLogger.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    alias Igniter.Code.Common
    alias Igniter.Project.Config

    # CLI option => `config :ramoops_logger` key
    @config_options [
      pmsg_path: :pmsg_path,
      pstore_mount_point: :pstore_mount_point,
      pmsg_log: :pmsg_log,
      pstore_auto_mount: :auto_mount?
    ]

    # Every place a stale `config :logger, backends: [RamoopsLogger]` could be
    @config_files ~w(config.exs target.exs host.exs dev.exs test.exs prod.exs runtime.exs)

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :ramoops_logger,
        example: __MODULE__.Docs.example(),
        schema: [
          pmsg_path: :string,
          pstore_mount_point: :string,
          pmsg_log: :string,
          pstore_auto_mount: :boolean
        ]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> remove_legacy_backend()
      |> configure_options()
      |> Igniter.add_notice("""
      RamoopsLogger needs Linux pstore support from your Nerves system:
      CONFIG_PSTORE, CONFIG_PSTORE_PMSG and CONFIG_PSTORE_RAM in the kernel and
      a ramoops reserved-memory region with a pmsg-size in the device tree.
      Most official Nerves systems have this. This installer cannot check or
      change it. On the device, look for /dev/pmsg0 to verify.

      After an unexpected reboot, run RamoopsLogger.dump() at the IEx prompt
      to see the errors logged before it.
      """)
    end

    defp configure_options(igniter) do
      # `--no-pstore-auto-mount` is `false`, so check for presence, not truthiness
      settings =
        for {option, key} <- @config_options,
            {:ok, value} <- [Keyword.fetch(igniter.args.options, option)],
            do: {key, value}

      nerves? = Igniter.exists?(igniter, "config/target.exs")
      file = if nerves?, do: "target.exs", else: "config.exs"

      igniter =
        Enum.reduce(settings, igniter, fn {key, value}, igniter ->
          Config.configure_new(igniter, file, :ramoops_logger, [key], value)
        end)

      if settings != [] and not nerves? do
        Igniter.add_notice(igniter, """
        No config/target.exs found, so the ramoops_logger settings were added
        to config/config.exs. They are meant for Nerves devices and also apply
        when running on your host.
        """)
      else
        igniter
      end
    end

    # RamoopsLogger was an Elixir Logger backend through v0.3. Leaving it in
    # the backends list logs an error on every boot.
    defp remove_legacy_backend(igniter) do
      Enum.reduce(@config_files, igniter, fn file, igniter ->
        if Igniter.exists?(igniter, "config/#{file}") and
             Config.configures_key?(igniter, file, :logger, :backends) do
          remove_legacy_backend(igniter, file)
        else
          igniter
        end
      end)
    end

    defp remove_legacy_backend(igniter, file) do
      Config.configure(igniter, file, :logger, [:backends], [],
        updater: fn zipper ->
          if Igniter.Code.List.list?(zipper) do
            Igniter.Code.List.remove_from_list(zipper, &ramoops_logger?/1)
          else
            # Not a literal list, so leave it for the user
            {:ok, zipper}
          end
        end
      )
    end

    defp ramoops_logger?(zipper) do
      Common.nodes_equal?(zipper, RamoopsLogger)
    end
  end
else
  defmodule Mix.Tasks.RamoopsLogger.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'ramoops_logger.install' requires igniter. Please install igniter and try again.

      For more information, see: https://igniter.hexdocs.pm/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
