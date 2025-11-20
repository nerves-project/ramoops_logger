# SPDX-FileCopyrightText: 2019 SmartRent
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule RamoopsLogger do
  @moduledoc """
  This is an in-memory logger for the Erlang Logger that can survive reboots.

  Install it by adding the handler in your `config/runtime.exs` or application start:

  ```elixir
  # In config/runtime.exs
  :logger.add_handler(:ramoops_logger, RamoopsLogger.Handler, %{
    pmsg_path: "/dev/pmsg0",
    recovered_log_path: "/sys/fs/pstore/pmsg-ramoops-0"
  })
  ```

  Or add it programmatically:

  ```elixir
  iex> RamoopsLogger.attach()
  :ok
  # Configure only if the defaults don't work on your system
  iex> RamoopsLogger.attach(pmsg_path: "/dev/pmsg1")
  ```

  After a reboot, you can check if a log exists by calling `available_log?/0`.
  """

  alias RamoopsLogger.Handler

  @default_pmsg_log_path "/sys/fs/pstore/pmsg-ramoops-0"
  @handler_id :ramoops_logger

  @typedoc """
  Options for configuring the handler:

  * `:pmsg_path` - Path to pmsg device (default is `/dev/pmsg0`)
  * `:recovered_log_path` - Path to recovered log files from previous boots
     (default is `/sys/fs/pstore/pmsg-ramoops-0`)

  These can be specified when attaching the handler:

  ```elixir
  RamoopsLogger.attach(pmsg_path: "/dev/pmsg1", recovered_log_path: "/sys/fs/pstore/pmsg-ramoops-1")
  ```
  """
  @type handler_option :: {:pmsg_path, Path.t()} | {:recovered_log_path, Path.t()}

  @doc """
  Attach the RamoopsLogger handler to the Erlang logger.

  ## Options

  See `t:handler_option/0` for available options.

  ## Examples

      iex> RamoopsLogger.attach()
      :ok

      iex> RamoopsLogger.attach(pmsg_path: "/dev/pmsg1")
      :ok
  """
  @spec attach([handler_option()]) :: :ok | {:error, term()}
  def attach(opts \\ []) do
    config =
      opts
      |> Enum.into(%{})
      |> Map.put_new(:recovered_log_path, get_recovered_log_path(opts))

    case :logger.add_handler(@handler_id, Handler, config) do
      :ok -> :ok
      {:error, {:already_exist, _}} -> :ok
      {:error, _} = error -> error
    end
  end

  @doc """
  Detach the RamoopsLogger handler from the Erlang logger.

  ## Examples

      iex> RamoopsLogger.detach()
      :ok
  """
  @spec detach() :: :ok | {:error, term()}
  def detach() do
    case :logger.remove_handler(@handler_id) do
      :ok -> :ok
      {:error, {:not_found, _}} -> :ok
      {:error, _} = error -> error
    end
  end

  @doc """
  Dump the contents of the ramoops pstore file to the console
  """
  @spec dump() :: :ok | {:error, File.posix()}
  def dump() do
    case File.read(recovered_log_path()) do
      {:ok, contents} -> IO.binwrite(contents)
      error -> error
    end
  end

  @doc """
  Read the file contents from the ramoops pstore file. This is useful if you
  want to pragmatically do something with the file contents, like post to an
  external server.
  """
  @spec read() :: {:ok, binary()} | {:error, File.posix()}
  def read() do
    File.read(recovered_log_path())
  end

  @doc """
  Check to see if there a log
  """
  @spec available_log?() :: boolean()
  def available_log?() do
    File.exists?(recovered_log_path())
  end

  @doc """
  Return the path to the recovered log

  The path won't exist if there was nothing to recover on boot.
  """
  @spec recovered_log_path() :: Path.t()
  def recovered_log_path() do
    # Try to get from handler config first, then fall back to default
    case :logger.get_handler_config(@handler_id) do
      {:ok, config} ->
        Map.get(config, :recovered_log_path, @default_pmsg_log_path)

      {:error, _} ->
        @default_pmsg_log_path
    end
  end

  defp get_recovered_log_path(opts) do
    Keyword.get(opts, :recovered_log_path, @default_pmsg_log_path)
  end
end
