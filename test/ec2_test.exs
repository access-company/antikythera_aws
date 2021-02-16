defmodule AntikytheraAws.Ec2Test do
  use ExUnit.Case
  alias Antikythera.Httpc
  alias AntikytheraAws.Ec2.ClusterConfiguration

  @region_args                    ["--region", Application.fetch_env!(:antikythera_aws, :region)]
  @auto_scaling_group_name        Application.fetch_env!(:antikythera_aws, :auto_scaling_group_name)
  @availability_zone_metadata_url "http://169.254.169.254/latest/meta-data/placement/availability-zone"

  test "running_hosts/0 should return healthy hosts" do
    :meck.expect(System, :cmd, fn(command, args, opts) ->
      assert command == "aws"
      assert opts    == [stderr_to_stdout: true]

      case args do
        [_, _, "autoscaling" | _] ->
          assert args == @region_args ++ ["autoscaling", "describe-auto-scaling-groups", "--auto-scaling-group-names", @auto_scaling_group_name]
          json =
            Poison.encode!(%{
              AutoScalingGroups: [
                %{
                  Instances: [
                    %{InstanceId: "i-0d87927817101e3d1", LifecycleState: "InService",        HealthStatus: "Healthy"},
                    %{InstanceId: "i-0d87927817101e3d2", LifecycleState: "Terminating:Wait", HealthStatus: "Healthy"},
                    %{InstanceId: "i-0d87927817101e3d3", LifecycleState: "Terminating:Wait", HealthStatus: "Unhealthy"}
                  ]
                }
              ]
            })
          {json, 0}
        [_, _, "ec2" | _] ->
          assert args == @region_args ++ ["ec2", "describe-instances", "--instance-ids", "i-0d87927817101e3d1", "i-0d87927817101e3d2"]
          json =
            Poison.encode!(%{
              Reservations: [
                %{
                  Instances: [
                    %{InstanceId: "i-0d87927817101e3d1", PrivateDnsName: "ip-172-31-22-131.ap-northeast-1.compute.internal"},
                    %{InstanceId: "i-0d87927817101e3d2", PrivateDnsName: "ip-172-31-22-132.ap-northeast-1.compute.internal"}
                  ]
                }
              ]
            })
          {json, 0}
      end
    end)

    assert ClusterConfiguration.running_hosts() == {:ok, %{"ip-172-31-22-131.ap-northeast-1.compute.internal" => true, "ip-172-31-22-132.ap-northeast-1.compute.internal" => false}}
  end

  test "zone_of_this_host/0 should return zone of the host" do
    :meck.expect(Httpc, :get!, fn(url) ->
      assert url == @availability_zone_metadata_url
      %Httpc.Response{
        status: 200,
        body: "ap-northeast-1",
        headers: %{},
        cookies: %{}
      }
    end)

    assert ClusterConfiguration.zone_of_this_host() == "ap-northeast-1"
  end

  test "health_check_grace_period/0 should return health check grace period" do
    :meck.expect(System, :cmd, fn(_, args, _) ->
      assert args == @region_args ++ ["autoscaling", "describe-auto-scaling-groups", "--auto-scaling-group-names", @auto_scaling_group_name]

      json =
        Poison.encode!(%{
          AutoScalingGroups: [
            %{
              HealthCheckGracePeriod: 400
            }
          ]
        })
      {json, 0}
    end)

    assert ClusterConfiguration.health_check_grace_period() == 400
  end
end
