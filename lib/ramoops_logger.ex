# SPDX-FileCopyrightText: 2019 SmartRent
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule RamoopsLogger do
  @moduledoc """
  This is an in-memory backend for the Elixir Logger that can survive reboots.

  Install it by adding it to your `config.exs`:

  ```elixir
  use Mix.Config

  config :logger, backends: [:console, RamoopsLogger]

  # The defaults
  config :logger, RamoopsLogger,
    pmsg_path: "/dev/pmsg1",
    recovered_log_path: "/sys/fs/pstore/pmsg-ramoops-1"
  ```

  Or add manually:

  ```elixir
  iex> Logger.add_backend(RamoopsLogger)
  :ok
  # Configure only if the defaults don't work on your system
  iex> Logger.configure(RamoopsLogger, pmsg_path: "/dev/pmsg1")
  ```

  After a reboot, you can check if a log exists by calling `available_log?/0`.
  """

  @behaviour :gen_event

  alias RamoopsLogger.Server

  @default_pmsg_log_path "/sys/fs/pstore/pmsg-ramoops-0"

  @typedoc """
  Options for configuring the backend:

  * `:pmsg_path` - Path to pmsg device (default is `/dev/pmsg0`)
  * `:recovered_log_path` - Path to recovered log files from previous boots
     (default is `/sys/fs/pstore/pmsg-ramoops-0`)

  These are either specified in the Application config (e.g., `config.exs`) like
  this:

  ```elixir
  config :logger, RamoopsLogger,
    pmsg_path: "/dev/pmsg1",
    recovered_log_path: "/sys/fs/pstore/pmsg-ramoops-1"
  ```

  Or configured at runtime like:

  ```elixir
  iex> Logger.configure(RamoopsLogger, pmsg_path: "/dev/pmsg1")
  ```
  """
  @type backend_option :: {:pmsg_path, Path.t()} | {:recovered_log_path, Path.t()}

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
    env = Application.get_env(:logger, __MODULE__, [])
    Keyword.get(env, :recovered_log_path, @default_pmsg_log_path)
  end

  #
  # Logger backend callbacks
  #
  @impl :gen_event
  def init(__MODULE__) do
    init({__MODULE__, []})
  end

  def init({__MODULE__, opts}) when is_list(opts) do
    env = Application.get_env(:logger, __MODULE__, [])
    opts = Keyword.merge(env, opts)
    Application.put_env(:logger, __MODULE__, opts)

    case Server.start_link(opts) do
      {:ok, pid} ->
        {:ok, pid}

      :ignore ->
        {:error, :ignore}

      error ->
        error
    end
  end

  @impl :gen_event
  def handle_event({_level, gl, _event}, state) when node(gl) != node() do
    # Ignore per Elixir Logger documentation
    {:ok, state}
  end

  def handle_event({level, _gl, message}, state) do
    Server.log(state, level, message)
    {:ok, state}
  end

  def handle_event(:flush, state) do
    # No flushing needed for RamoopsLogger
    {:ok, state}
  end

  @impl :gen_event
  def handle_call({:configure, opts}, state) do
    {:ok, Server.configure(state, opts), state}
  end

  def handle_call(_request, state) do
    # Ignore to avoid crashing on bad messages
    {:ok, {:error, :unimplemented}, state}
  end

  @impl :gen_event
  def handle_info(_, state) do
    {:ok, state}
  end

  @impl :gen_event
  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  @impl :gen_event
  def terminate(_reason, state) do
    Server.stop(state)
  end
end
