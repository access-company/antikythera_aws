# Copyright(c) 2015-2021 ACCESS CO., LTD. All rights reserved.

use Croma
alias Croma.Result, as: R

defmodule AntikytheraAws.Ec2.ClusterConfiguration do
  @behaviour AntikytheraEal.ClusterConfiguration.Behaviour

  alias Antikythera.Httpc
  require AntikytheraCore.Logger, as: L

  @region                         Application.fetch_env!(:antikythera_aws, :region)
  @auto_scaling_group_name        Application.fetch_env!(:antikythera_aws, :auto_scaling_group_name)
  @availability_zone_metadata_url "http://169.254.169.254/latest/meta-data/placement/availability-zone"

  @impl true
  defun running_hosts() :: R.t(%{String.t => boolean}) do
    run_cli(["autoscaling", "describe-auto-scaling-groups", "--auto-scaling-group-names", @auto_scaling_group_name], fn j1 ->
      id_status_map = make_id_status_map(j1)
      run_cli(["ec2", "describe-instances", "--instance-ids" | Map.keys(id_status_map)], fn j2 ->
        make_id_private_dns_name_map(j2)
        |> Map.new(fn {id, dns_name} -> {dns_name, Map.fetch!(id_status_map, id)} end)
        |> R.pure()
      end)
    end)
  end

  defp run_cli(args, f) do
    args_all = ["--region", @region | args]
    case System.cmd("aws", args_all, [stderr_to_stdout: true]) do
      {json, 0}          -> f.(Poison.decode!(json))
      {output, _nonzero} ->
        L.error("aws-cli with args #{inspect(args_all)} returned nonzero status: #{output}")
        {:error, :script_error}
    end
  end

  defp make_id_status_map(decoded) do
    decoded
    |> Map.fetch!("AutoScalingGroups")
    |> hd() # Only 1 auto scaling group name is given to aws-cli describe-auto-scaling-groups command
    |> Map.fetch!("Instances")
    |> Enum.filter(fn %{"HealthStatus" => s} -> s == "Healthy" end)
    |> Map.new(fn %{"InstanceId" => id, "LifecycleState" => state} -> {id, state == "InService"} end)
  end

  defp make_id_private_dns_name_map(decoded) do
    decoded
    |> Map.fetch!("Reservations")
    |> Enum.flat_map(fn %{"Instances" => is} -> is end)
    |> Map.new(fn %{"InstanceId" => id, "PrivateDnsName" => name} -> {id, name} end)
  end

  @impl true
  defun zone_of_this_host() :: String.t do
    %Httpc.Response{body: body} = Httpc.get!(@availability_zone_metadata_url)
    body
  end
end
