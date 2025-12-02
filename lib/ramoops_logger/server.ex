# SPDX-FileCopyrightText: 2019 SmartRent
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule RamoopsLogger.Server do
  @moduledoc false

  use GenServer
  require Logger

  @default_pmsg_path "/dev/pmsg0"

  @spec start_link([RamoopsLogger.backend_option()]) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Update the logger configuration.

  Options include:
  * `:pmsg_path` - path to pmsg device (default is `/dev/pmsg0`)
  """
  @spec configure(GenServer.server(), [RamoopsLogger.backend_option()]) :: :ok
  def configure(server, opts) do
    GenServer.call(server, {:configure, opts})
  end

  @doc """
  Log the logger message to the file
  """
  @spec log(
          GenServer.server(),
          Logger.level(),
          {Logger, Logger.message(), Logger.Formatter.time_ms(), Logger.metadata()}
        ) :: :ok
  def log(server, level, message) do
    GenServer.cast(server, {:log, level, message})
  end

  @doc """
  Stop the server
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(server) do
    GenServer.stop(server, :normal)
  end

  @impl GenServer
  def init(opts) do
    opts = merge_and_update_opts(opts)

    case open_pmsg(opts) do
      {:ok, fd} ->
        state = %{fd: fd, format: Logger.Formatter.compile(nil)}

        {:ok, state}

      {:error, reason} ->
        Logger.error(reason)
        :ignore
    end
  end

  @impl GenServer
  def handle_call({:configure, opts}, _from, state) do
    opts = merge_and_update_opts(opts)

    _ = File.close(state.fd)

    case open_pmsg(opts) do
      {:ok, new_fd} ->
        new_state = %{state | fd: new_fd}

        {:reply, :ok, new_state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_cast({:log, level, message}, state) do
    output = apply_format(state.format, level, message)
    _ = IO.binwrite(state.fd, output)
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_, state) do
    File.close(state.fd)
  end

  defp merge_and_update_opts(opts) do
    env = Application.get_env(:logger, RamoopsLogger, [])
    opts = Keyword.merge(env, opts)
    Application.put_env(:logger, RamoopsLogger, opts)
    opts
  end

  defp open_pmsg(opts) do
    path = Keyword.get(opts, :pmsg_path, @default_pmsg_path)

    with true <- File.exists?(path),
         {:ok, fd} <- File.open(path, [:append]) do
      {:ok, fd}
    else
      _ -> {:error, "Unable to open '#{path}'. RamoopsLogger won't work."}
    end
  end

  defp apply_format(format, level, {_, message, ts, _meta}) do
    Logger.Formatter.format(format, level, message, ts, [])
  end
end
