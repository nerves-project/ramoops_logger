# SPDX-FileCopyrightText: 2019 SmartRent
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule RamoopsLogger do
  @moduledoc """
  This module provides an in-memory log handler for the Erlang logger that can survive reboots.

  After a reboot, you can check if a log exists by calling `available_log?/0`.
  """
  require Logger

  @doc """
  Dump the contents of the ramoops pstore file to the console
  """
  @spec dump() :: :ok | {:error, File.posix()}
  def dump() do
    case read() do
      {:ok, contents} -> contents |> String.replace_invalid() |> IO.write()
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
    with :ok <- maybe_mount_pstore() do
      File.read(recovered_log_path())
    end
  end

  @doc """
  Check to see if there a log
  """
  @spec available_log?() :: boolean()
  def available_log?() do
    case maybe_mount_pstore() do
      :ok -> File.exists?(recovered_log_path())
      _ -> false
    end
  end

  @doc """
  Return the path to the recovered log

  The path won't exist if there was nothing to recover on boot.
  """
  @spec recovered_log_path() :: Path.t()
  def recovered_log_path() do
    pmsg_log = Application.fetch_env!(:ramoops_logger, :pmsg_log)
    pstore_mount_point = Application.fetch_env!(:ramoops_logger, :pstore_mount_point)

    Path.join(pstore_mount_point, pmsg_log)
  end

  defp maybe_mount_pstore() do
    pstore_mount_point = Application.fetch_env!(:ramoops_logger, :pstore_mount_point)
    parent_dir = Path.dirname(pstore_mount_point)

    with :no <- ok_to_skip(),
         {:ok, parent_stat} <- File.stat(parent_dir),
         {:ok, pstore_stat} <- File.stat(pstore_mount_point) do
      # The mount point should exist, but it hasn't been mounted if it's still the same
      # device as the parent directory.
      if parent_stat.major_device == pstore_stat.major_device and
           parent_stat.minor_device == pstore_stat.minor_device do
        mount_pstore(pstore_mount_point)
      else
        :ok
      end
    end
  end

  defp ok_to_skip() do
    case Application.fetch_env!(:ramoops_logger, :auto_mount?) do
      true -> :no
      _ -> :ok
    end
  end

  defp mount_pstore(pstore_mount_point) do
    case System.cmd("mount", ["-t", "pstore", "pstore", pstore_mount_point]) do
      {_, 0} -> :ok
      _ -> {:error, :eio}
    end
  end

  # Notify anyone who upgrades to not forget to remove the Elixir Logger backend configuration
  @doc false
  @spec init(term()) :: {:error, :ignore}
  def init(_) do
    Logger.error(
      "RamoopsLogger is no longer an Elixir Logger backend. Please remove it from your Logger config"
    )

    {:error, :ignore}
  end
end
