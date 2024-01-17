# Copyright(c) 2015-2024 ACCESS CO., LTD. All rights reserved.

use Croma
alias Croma.Result, as: R

defmodule AntikytheraAws.Imds do
  @moduledoc """
  Provides a method to get info from IMDSv2.
  """

  alias Antikythera.Httpc
  alias Antikythera.Httpc.Response

  @imds_endpoint "http://169.254.169.254"
  @imds_token_path "/latest/api/token"

  defun get(path :: String.t()) :: R.t(Response.t()) do
    R.m do
      %Response{body: token} <-
        Httpc.put(@imds_endpoint <> @imds_token_path, "", %{
          "X-aws-ec2-metadata-token-ttl-seconds" => "20"
        })

      Httpc.get(@imds_endpoint <> path, %{"X-aws-ec2-metadata-token" => token})
    end
  end

  defun get!(path :: String.t()) :: Response.t() do
    get(path) |> R.get!()
  end
end
