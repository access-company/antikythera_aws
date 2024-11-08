defmodule AntikytheraAws.Ec2.ClusterConfigurationTest do
  use Croma.TestCase
  alias Antikythera.Httpc

  @region_args ["--region", Application.compile_env!(:antikythera_aws, :region)]
  @auto_scaling_group_name Application.compile_env!(:antikythera_aws, :auto_scaling_group_name)
  @availability_zone_metadata_path "/latest/meta-data/placement/availability-zone"
  @node_a_instance_id "i-0d87927817101e3d1"
  @node_b_instance_id "i-0d87927817101e3d2"
  @node_c_instance_id "i-0d87927817101e3d3"
  @node_a_private_dns_name "ip-172-31-22-131.ap-northeast-1.compute.internal"
  @node_b_private_dns_name "ip-172-31-22-132.ap-northeast-1.compute.internal"

  setup do
    :meck.new(System, [:passthrough])
    on_exit(&:meck.unload/0)
  end

  test "running_hosts/0 should return the healthy EC2 instances with the status of InService" do
    :meck.expect(System, :cmd, fn command, [_, _, aws_command | _] = args, opts ->
      assert command == "aws"
      assert opts == [stderr_to_stdout: true]

      case aws_command do
        "autoscaling" ->
          assert args ==
                   @region_args ++
                     [
                       "autoscaling",
                       "describe-auto-scaling-groups",
                       "--auto-scaling-group-names",
                       @auto_scaling_group_name
                     ]

          json =
            Jason.encode!(%{
              AutoScalingGroups: [
                %{
                  Instances: [
                    %{
                      InstanceId: @node_a_instance_id,
                      LifecycleState: "InService",
                      HealthStatus: "Healthy"
                    },
                    %{
                      InstanceId: @node_b_instance_id,
                      LifecycleState: "Terminating:Wait",
                      HealthStatus: "Healthy"
                    },
                    %{
                      InstanceId: @node_c_instance_id,
                      LifecycleState: "Terminating:Wait",
                      HealthStatus: "Unhealthy"
                    }
                  ]
                }
              ]
            })

          {json, 0}

        "ec2" ->
          assert args ==
                   @region_args ++
                     [
                       "ec2",
                       "describe-instances",
                       "--instance-ids",
                       @node_a_instance_id,
                       @node_b_instance_id
                     ]

          json =
            Jason.encode!(%{
              Reservations: [
                %{
                  Instances: [
                    %{InstanceId: @node_a_instance_id, PrivateDnsName: @node_a_private_dns_name},
                    %{InstanceId: @node_b_instance_id, PrivateDnsName: @node_b_private_dns_name}
                  ]
                }
              ]
            })

          {json, 0}
      end
    end)

    assert ClusterConfiguration.running_hosts() ==
             {:ok, %{@node_a_private_dns_name => true, @node_b_private_dns_name => false}}
  end

  test "zone_of_this_host/0 should return the Availability Zone of this EC2 instance" do
    :meck.expect(AntikytheraAws.Imds, :get!, fn path ->
      assert path == @availability_zone_metadata_path

      %Httpc.Response{
        status: 200,
        body: "ap-northeast-1a",
        headers: %{},
        cookies: %{}
      }
    end)

    assert ClusterConfiguration.zone_of_this_host() == "ap-northeast-1a"
  end

  describe "health_check_grace_period_in_seconds/0" do
    test "should return the health check grace period of the Auto Scaling group" do
      :meck.expect(System, :cmd, fn _, args, _ ->
        assert args ==
                 @region_args ++
                   [
                     "autoscaling",
                     "describe-auto-scaling-groups",
                     "--auto-scaling-group-names",
                     @auto_scaling_group_name
                   ]

        json =
          Jason.encode!(%{
            AutoScalingGroups: [
              %{
                HealthCheckGracePeriod: 400
              }
            ]
          })

        {json, 0}
      end)

      assert ClusterConfiguration.health_check_grace_period_in_seconds() == 400
    end

    @tag capture_log: true
    test "should return the default value if fetching the health check grace period failed" do
      :meck.expect(System, :cmd, fn _, args, _ ->
        assert args ==
                 @region_args ++
                   [
                     "autoscaling",
                     "describe-auto-scaling-groups",
                     "--auto-scaling-group-names",
                     @auto_scaling_group_name
                   ]

        {"Error happened!", 1}
      end)

      assert ClusterConfiguration.health_check_grace_period_in_seconds() == 300
    end
  end
end
