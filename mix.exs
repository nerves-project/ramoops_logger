defmodule RamoopsLogger.MixProject do
  use Mix.Project

  @app :ramoops_logger
  @version "0.4.0"
  @source_url "https://github.com/nerves-project/ramoops_logger"

  @otp_release :erlang.system_info(:otp_release) |> List.to_integer()
  if @otp_release < 27 do
    raise "RamoopsLogger requires OTP 27 or later. You are using OTP #{@otp_release}."
  end

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      dialyzer: [
        flags: [:missing_return, :extra_return, :unmatched_returns, :error_handling, :underspecs]
      ]
    ]
  end

  def application do
    [
      env: [
        pmsg_path: "/dev/pmsg0",
        pstore_mount_point: "/sys/fs/pstore",
        pmsg_log: "pmsg-ramoops-0",
        auto_mount?: true
      ],
      extra_applications: [:logger, :sasl],
      mod: {RamoopsLogger.Application, []}
    ]
  end

  def cli do
    [preferred_envs: %{docs: :docs, "hex.build": :docs, "hex.publish": :docs}]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.19", only: :docs, runtime: false},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:test, :dev], runtime: false}
    ]
  end

  defp description do
    "Elixir Logger for Linux Ramoops"
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{
        "Changelog" => "https://hexdocs.pm/#{@app}/changelog.html",
        "GitHub" => @source_url,
        "REUSE Compliance" => "https://api.reuse.software/info/github.com/nerves-project/#{@app}"
      }
    ]
  end

  defp docs do
    [
      extras: ["README.md", "CHANGELOG.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
