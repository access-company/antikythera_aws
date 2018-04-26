# Copyright(c) 2015-2018 ACCESS CO., LTD. All rights reserved.

use Mix.Config

# Import config.exs in antikythera for testing
repo_dir = Path.expand("..", __DIR__)
antikythera_config_file = Path.join([repo_dir, "deps", "solomon", "config", "config.exs"])
if File.regular?(antikythera_config_file) do
  import_config antikythera_config_file
end

config :antikythera_aws, [
  # AWS region.
  # Used by `AntikytheraAws.Ec2.ClusterConfiguration`, `AntikytheraAws.S3.LogStorage` and `AntikytheraAws.S3.AssetStorage`.
  region: "ap-northeast-1",

  # Name of the auto scaling group of EC2 instances.
  # Used by `AntikytheraAws.Ec2.ClusterConfiguration`.
  auto_scaling_group_name: "antikythera-erlangnodes",

  # Name of S3 bucket to store rotated log files.
  # Used by `AntikytheraAws.S3.LogStorage`.
  log_storage_bucket: "antikythera-logs",

  # Name of S3 bucket to store asset files. See also `Antikythera.Asset`.
  # Used by `AntikytheraAws.S3.AssetStorage`.
  asset_storage_bucket: "antikythera-assets",
]
