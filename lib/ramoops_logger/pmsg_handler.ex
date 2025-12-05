# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule RamoopsLogger.PmsgHandler do
  @moduledoc """
  Minimal Erlang logger handler that writes log events to /dev/pmsg0.

  This cannot use `:logger_std_h` since that calls `:file.sync/1` which
  isn't supported by /dev/pmsg0.
  """

  @behaviour :logger_handler

  alias RamoopsLogger.PmsgWriter

  @impl :logger_handler
  def adding_handler(config) do
    case PmsgWriter.start_link(config) do
      {:ok, pid} -> {:ok, Map.put(config, :writer, pid)}
      {:error, reason} -> {:error, {:pmsg_open_failed, reason}}
    end
  end

  @impl :logger_handler
  def removing_handler(%{writer: pid}) do
    GenServer.stop(pid)
  end

  def removing_handler(_config), do: :ok

  @impl :logger_handler
  def changing_config(_set_or_update, old_config, new_config) do
    # Preserve the writer across config changes
    merged =
      Map.merge(old_config, new_config, fn
        :writer, old_writer, _new -> old_writer
        _key, _old, new -> new
      end)

    {:ok, merged}
  end

  @impl :logger_handler
  def log(log_event, config) do
    PmsgWriter.log(config.writer, log_event)
    config
  end
end
