# Copyright(c) 2015-2024 ACCESS CO., LTD. All rights reserved.

defmodule AntikytheraAws.MixProject do
  use Mix.Project

  @github_url "https://github.com/access-company/antikythera_aws"

  @version "0.4.0"
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
      {:antikythera,
       [
         git: "git@github.com:access-company/antikythera.git",
         ref: "1d56aaaeced13f38ae6db916f56cd9a2299c2292"
       ]},
      {:ex_doc, "~> 0.40.1", [only: :dev, runtime: false]},
      {:dialyxir, "~> 1.4.7", [only: :dev, runtime: false]},
      {:credo, "~> 1.7.17", [only: :dev, runtime: false]},
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
