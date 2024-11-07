# Copyright(c) 2015-2024 ACCESS CO., LTD. All rights reserved.

defmodule AntikytheraAws.MixProject do
  use Mix.Project

  @github_url "https://github.com/access-company/antikythera_aws"

  @version "0.3.1"
  @release false

  if @release do
    @source_ref @version
  else
    @source_ref "master"
  end

  def project() do
    [
      app: :antikythera_aws,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      source_url: @github_url,
      homepage_url: @github_url,
      description:
        "Implementations of some of pluggable modules in the Antikythera Framework, using AWS services.",
      package: package(),
      docs: [source_ref: @source_ref]
    ]
  end

  def application() do
    [
      extra_applications: [:logger, :croma, :poison]
    ]
  end

  defp deps() do
    [
      {:antikythera, "~> 0.5"},
      {:ex_doc, "~> 0.33.0", [only: :dev, runtime: false]},
      {:dialyxir, "~> 1.4.4", [only: :dev, runtime: false]},
      {:credo, "~> 1.7.8", [only: :dev, runtime: false]},
      {:meck, "~> 0.9.2", [only: :test]}
    ]
  end

  defp package() do
    [
      licenses: ["Apache 2.0"],
      maintainers: ["antikythera-gr@access-company.com"],
      links: %{"GitHub" => @github_url},
      files: ["lib", "LICENSE", "mix.exs", "README.md"]
    ]
  end
end
