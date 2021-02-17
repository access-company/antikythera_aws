defmodule AntikytheraAws.Ec2.ClusterConfigurationTest do
  use Croma.TestCase
  alias Antikythera.Httpc

  @region_args                    ["--region", Application.fetch_env!(:antikythera_aws, :region)]
  @auto_scaling_group_name        Application.fetch_env!(:antikythera_aws, :auto_scaling_group_name)
  @availability_zone_metadata_url "http://169.254.169.254/latest/meta-data/placement/availability-zone"
  @noda_a_instance_id             "i-0d87927817101e3d1"
  @noda_b_instance_id             "i-0d87927817101e3d2"
  @noda_c_instance_id             "i-0d87927817101e3d3"
  @node_a_private_dns_name        "ip-172-31-22-131.ap-northeast-1.compute.internal"
  @node_b_private_dns_name        "ip-172-31-22-132.ap-northeast-1.compute.internal"

  test "running_hosts/0 should return the healthy EC2 instances with the status of InService" do
    :meck.expect(System, :cmd, fn(command, [_, _, aws_command | _] = args, opts) ->
      assert command == "aws"
      assert opts    == [stderr_to_stdout: true]

      case aws_command do
        "autoscaling" ->
          assert args == @region_args ++ ["autoscaling", "describe-auto-scaling-groups", "--auto-scaling-group-names", @auto_scaling_group_name]
          json =
            Poison.encode!(%{
              AutoScalingGroups: [
                %{
                  Instances: [
                    %{InstanceId: @noda_a_instance_id, LifecycleState: "InService",        HealthStatus: "Healthy"},
                    %{InstanceId: @noda_b_instance_id, LifecycleState: "Terminating:Wait", HealthStatus: "Healthy"},
                    %{InstanceId: @noda_c_instance_id, LifecycleState: "Terminating:Wait", HealthStatus: "Unhealthy"}
                  ]
                }
              ]
            })
          {json, 0}
        "ec2" ->
          assert args == @region_args ++ ["ec2", "describe-instances", "--instance-ids", @noda_a_instance_id, @noda_b_instance_id]
          json =
            Poison.encode!(%{
              Reservations: [
                %{
                  Instances: [
                    %{InstanceId: @noda_a_instance_id, PrivateDnsName: @node_a_private_dns_name},
                    %{InstanceId: @noda_b_instance_id, PrivateDnsName: @node_b_private_dns_name}
                  ]
                }
              ]
            })
          {json, 0}
      end
    end)

    assert ClusterConfiguration.running_hosts() == {:ok, %{@node_a_private_dns_name => true, @node_b_private_dns_name => false}}
  end

  test "zone_of_this_host/0 should return the Availability Zone of this EC2 instance" do
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

  test "health_check_grace_period/0 should return the health check grace period of the Auto Scaling group" do
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
