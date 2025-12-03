# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule RamoopsLogger.PmsgWriter do
  @moduledoc false
  use GenServer

  @spec start_link(:logger_handler.config()) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  @spec log(GenServer.server(), :logger.log_event()) :: :ok
  def log(server, log_event) do
    GenServer.cast(server, {:log, log_event})
  end

  @impl GenServer
  def init(config) do
    pmsg_path = Keyword.fetch!(config.config, :pmsg_path)
    {formatter, formatter_options} = config.formatter

    # Ensure that the pmsg file exists so we don't create a regular file
    with {:ok, _} <- File.stat(pmsg_path),
         {:ok, io} <- File.open(pmsg_path, [:write]) do
      {:ok, %{io: io, formatter: formatter, formatter_options: formatter_options}}
    else
      {:error, reason} -> {:stop, {:pmsg_open_failed, reason}}
    end
  end

  @impl GenServer
  def handle_cast({:log, log_event}, state) do
    IO.puts(state.io, state.formatter.format(log_event, state.formatter_options))
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, %{io: io}) do
    _ = File.close(io)
    :ok
  end
end
