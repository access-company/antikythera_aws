# Copyright(c) 2015-2018 ACCESS CO., LTD. All rights reserved.

defmodule AntikytheraAws.MixProject do
  use Mix.Project

  def project() do
    [
      app:             :antikythera_aws,
      version:         "0.1.0",
      elixir:          "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps:            deps(),
    ]
  end

  def application() do
    [
      extra_applications: [:logger, :croma, :poison],
    ]
  end

  defp deps() do
    [
      {:antikythera, "~> 0.2"},
      {:ex_doc     , "~> 0.18", [only: :dev , runtime: false]},
      {:dialyze    , "~> 0.2" , [only: :dev , runtime: false]},
      {:credo      , "~> 0.8" , [only: :dev , runtime: false]},
      {:meck       , "~> 0.8" , [only: :test]},
    ]
  end
end
