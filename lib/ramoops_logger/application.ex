# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule RamoopsLogger.Application do
  @moduledoc false
  use Application

  alias RamoopsLogger.PmsgHandler
  require Logger

  @impl Application
  def start(_type, _args) do
    config = Application.get_all_env(:ramoops_logger)

    result =
      :logger.add_handler(
        :ramoops_logger,
        PmsgHandler,
        %{
          config: config,
          level: :error,
          formatter:
            {:logger_formatter,
             %{
               time_offset: ?Z,
               template: [
                 :time,
                 " ",
                 {:application, [:application], ["unknown"]},
                 " ",
                 :msg
               ]
             }}
        }
      )

    if result != :ok do
      Logger.error("Failed to add ramoops_logger log handler: #{inspect(result)}")
    end

    opts = [strategy: :one_for_one, name: RamoopsLogger.Supervisor]
    Supervisor.start_link([], opts)
  end

  @impl Application
  def stop(_state) do
    _ = :logger.remove_handler(:ramoops_logger)

    :ok
  end
end
