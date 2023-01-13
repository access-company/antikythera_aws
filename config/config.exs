# Copyright(c) 2015-2023 ACCESS CO., LTD. All rights reserved.

use Mix.Config

# Import mandatory antikythera configurations for development/testing.
# They should be supplied by antikythera instances when this package is used as a dependency.
dep_antikythera_dir = Path.expand(Path.join([__DIR__, "..", "deps", "antikythera"]))
if File.dir?(dep_antikythera_dir) do
  Code.require_file(Path.join([dep_antikythera_dir, "mix_common.exs"])) # Loads Antikythera.MixConfig
  import_config Path.join([dep_antikythera_dir, "config", "config.exs"])
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
