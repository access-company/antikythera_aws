# AntikytheraAws

[![hex badge](https://img.shields.io/hexpm/v/antikythera_aws.svg)](https://hex.pm/packages/antikythera_aws)

Implementations of some of pluggable modules in the [Antikythera Framework](https://github.com/access-company/antikythera), using AWS services.

## Components

- `AntikytheraAws.Ec2.ClusterConfiguration`: callback module of `AntikytheraEal.ClusterConfiguration.Behaviour`
- `AntikytheraAws.S3.LogStorage`: callback module of `AntikytheraEal.LogStorage.Behaviour`
- `AntikytheraAws.S3.AssetStorage`: callback module of `AntikytheraEal.AssetStorage.Behaviour`
- and some more AWS-related utilities

## Dependencies

Other than the standard mix dependencies, `AntikytheraAws` depends on the followings:

- [aws-cli](https://github.com/aws/aws-cli)
    - Assuming that the AWS-related features are not frequently used, interactions with AWS APIs are delegated to `aws-cli`.
- [EC2 instance profile](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html)
    - When making requests to AWS APIs (via `aws-cli`), IAM role stored in the EC2 instance profile is used.

## Copyright and License

Copyright(c) 2015-2023 [ACCESS CO., LTD](https://www.access-company.com). All rights reserved.

Antikythera source code is licensed under the [Apache License version 2.0](./LICENSE).
