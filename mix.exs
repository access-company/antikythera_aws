# Copyright(c) 2015-2021 ACCESS CO., LTD. All rights reserved.

defmodule AntikytheraAws.MixProject do
  use Mix.Project

  @github_url "https://github.com/access-company/antikythera_aws"

  def project() do
    [
      app: :antikythera_aws,
      version: "0.2.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      source_url: @github_url,
      homepage_url: @github_url,
      description:
        "Implementations of some of pluggable modules in the Antikythera Framework, using AWS services.",
      package: package()
    ]
  end

  def application() do
    [
      extra_applications: [:logger, :croma, :poison]
    ]
  end

  defp deps() do
    [
      {:antikythera, "~> 0.4"},
      {:ex_doc, "~> 0.18", [only: :dev, runtime: false]},
      {:dialyxir, "~> 0.5", [only: :dev, runtime: false]},
      {:credo, "~> 1.4.0", [only: :dev, runtime: false]},
      {:meck, "~> 0.8", [only: :test]}
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
