# SPDX-FileCopyrightText: 2019 SmartRent
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule RamoopsLogger.Handler do
  @moduledoc false
  # Erlang :logger handler implementation for RamoopsLogger
  #
  # This handler uses a GenServer to maintain the file descriptor
  # since the handler callbacks run in different processes.

  use GenServer

  @default_pmsg_path "/dev/pmsg0"

  # Erlang logger handler callbacks

  @doc """
  Called when the handler is being added to the logger.
  """
  def adding_handler(config) do
    # Start a GenServer to hold the file descriptor
    case start_link(config) do
      {:ok, pid} ->
        # Store the GenServer pid in the config
        new_config = Map.put(config, :server_pid, pid)
        {:ok, new_config}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Called when configuration is changed
  """
  def changing_config(_set_or_update, old_config, new_config) do
    # Get the server pid from old config
    case Map.get(old_config, :server_pid) do
      nil ->
        # No server running, start one
        adding_handler(new_config)

      pid ->
        # Update the existing server's configuration
        GenServer.call(pid, {:configure, new_config})
        {:ok, Map.put(new_config, :server_pid, pid)}
    end
  end

  @doc """
  Called when the handler is being removed.
  """
  def removing_handler(config) do
    case Map.get(config, :server_pid) do
      nil ->
        :ok

      pid ->
        GenServer.stop(pid, :normal)
        :ok
    end
  end

  @doc """
  Main logging callback - called for each log event
  """
  def log(log_event, config) do
    case Map.get(config, :server_pid) do
      nil ->
        :ok

      pid ->
        GenServer.cast(pid, {:log, log_event})
        :ok
    end
  end

  # GenServer implementation

  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  @impl GenServer
  def init(config) do
    case open_pmsg(config) do
      {:ok, fd} ->
        state = %{fd: fd, config: config}
        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call({:configure, new_config}, _from, state) do
    # Close old file and open new one if path changed
    old_path = Map.get(state.config, :pmsg_path, @default_pmsg_path)
    new_path = Map.get(new_config, :pmsg_path, @default_pmsg_path)

    if old_path != new_path do
      _ = File.close(state.fd)

      case open_pmsg(new_config) do
        {:ok, new_fd} ->
          new_state = %{state | fd: new_fd, config: new_config}
          {:reply, :ok, new_state}

        {:error, reason} ->
          {:stop, reason, state}
      end
    else
      new_state = %{state | config: new_config}
      {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_cast({:log, log_event}, state) do
    output = format_event(log_event)
    _ = IO.binwrite(state.fd, output)
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    File.close(state.fd)
  end

  # Private functions

  defp open_pmsg(config) do
    config_map = if is_map(config), do: config, else: Map.new(config)
    path = Map.get(config_map, :pmsg_path, @default_pmsg_path)

    case File.open(path, [:append]) do
      {:ok, fd} ->
        {:ok, fd}

      {:error, reason} ->
        {:error, "Unable to open '#{path}' (#{inspect(reason)}). RamoopsLogger won't work."}
    end
  end

  defp format_event(log_event) do
    # Extract information from the log event
    # Erlang logger events are maps with keys like :level, :msg, :meta
    level = Map.get(log_event, :level, :info)
    msg = Map.get(log_event, :msg, "")

    # Format the message
    formatted_msg = format_message(msg)

    # Simple format: [level] message\n
    "[#{level}] #{formatted_msg}\n"
  end

  defp format_message({:string, chardata}) when is_list(chardata) do
    IO.chardata_to_string(chardata)
  end

  defp format_message({:string, string}) when is_binary(string) do
    string
  end

  defp format_message({:report, report}) do
    inspect(report)
  end

  defp format_message(msg) do
    inspect(msg)
  end
end
