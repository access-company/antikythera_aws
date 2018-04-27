# Copyright(c) 2015-2018 ACCESS CO., LTD. All rights reserved.

use Croma

defmodule AntikytheraAws.S3 do
  alias Antikythera.GearName
  alias AntikytheraCore.Path, as: CorePath
  alias AntikytheraAws.Auth.{Credentials, InstanceProfileCredentials}

  @region Application.fetch_env!(:antikythera_aws, :region)

  defun list_objects(bucket :: v[String.t], key_prefix :: v[String.t]) :: [{String.t, non_neg_integer}] do
    case System.cmd("aws", ["s3", "ls", "s3://#{bucket}/#{key_prefix}", "--recursive"]) do
      {lines, 0} ->
        String.split(lines, "\n", trim: true) |> Enum.map(fn line ->
          [_date, _time, size_str, key | _rest] = String.split(line)
          {key, String.to_integer(size_str)}
        end)
      {"", 1} -> []
    end
  end

  defun generate_presigned_urls(bucket :: v[String.t], obj_keys :: [String.t], expires_in_seconds :: v[pos_integer]) :: [String.t] do
    expires = System.system_time(:seconds) + expires_in_seconds
    %Credentials{access_key_id: access_key, secret_access_key: secret_key, security_token: token} = InstanceProfileCredentials.credentials()
    Enum.map(obj_keys, fn obj_key ->
      generate_impl(bucket, obj_key, access_key, secret_key, token, expires)
    end)
  end

  defp generate_impl(bucket, obj_key, access_key, secret_key, token, expires) do
    signature_raw = "GET\n\n\n#{expires}\nx-amz-security-token:#{token}\n/#{bucket}/#{obj_key}"
    signature = :crypto.hmac(:sha, secret_key, signature_raw) |> Base.encode64()
    params = [
      {"AWSAccessKeyId"      , access_key},
      {"Expires"             , expires   },
      {"Signature"           , signature },
      {"x-amz-security-token", token     },
    ]
    "https://s3-#{@region}.amazonaws.com/#{bucket}/#{obj_key}?#{URI.encode_query(params)}"
  end

  defmodule LogStorage do
    alias AntikytheraCore.Cluster.NodeId
    alias AntikytheraAws.S3

    @bucket_name            Application.fetch_env!(:antikythera_aws, :log_storage_bucket)
    @presigned_url_lifetime 600

    @behaviour AntikytheraEal.LogStorage.Behaviour

    @impl true
    defun list(gear_name :: v[GearName.t], date_str :: v[String.t]) :: [{String.t, non_neg_integer}] do
      S3.list_objects(@bucket_name, "logs/#{gear_name}/#{date_str}/")
    end

    @impl true
    defun download_urls(keys :: v[[String.t]]) :: [String.t] do
      S3.generate_presigned_urls(@bucket_name, keys, @presigned_url_lifetime)
    end

    @impl true
    defun upload_rotated_logs(gear_name :: v[GearName.t]) :: :ok do
      dir = CorePath.gear_log_dir(gear_name)
      s3_key_prefix = "logs/#{gear_name}/#{today_str()}/#{NodeId.get()}/"
      {_, 0} = System.cmd("aws", ["s3", "mv", dir, "s3://#{@bucket_name}/#{s3_key_prefix}", "--recursive", "--exclude", "#{gear_name}.log.gz"])
      :ok
    end

    defp today_str() do
      import Antikythera.StringFormat
      {y, m, d} = :erlang.date()
      "#{y}#{pad2(m)}#{pad2(d)}"
    end
  end

  defmodule AssetStorage do
    @bucket_name   Application.fetch_env!(:antikythera_aws, :asset_storage_bucket)
    @cache_control "public, max-age=31536000"

    @behaviour AntikytheraEal.AssetStorage.Behaviour

    @impl true
    defun list(gear_name :: v[GearName.t]) :: [String.t] do
      request_to_s3api("list-objects-v2", ["--prefix", "#{gear_name}/"])
      |> Map.get("Contents", [])
      |> Enum.map(fn %{"Key" => key} -> key end)
    end

    @impl true
    defun list_toplevel_prefixes() :: [String.t] do
      request_to_s3api("list-objects-v2", ["--delimiter", "/"])
      |> Map.get("CommonPrefixes", [])
      |> Enum.map(fn %{"Prefix" => prefix} -> String.trim_trailing(prefix, "/") end)
    end

    @impl true
    defun upload(path :: Path.t, key :: v[String.t], mime :: v[String.t], gzip? :: v[boolean]) :: :ok do
      common_args = [
        "--key"          , key,
        "--cache-control", @cache_control,
        "--content-type" , mime,
      ]
      args =
        if gzip? do
          [] = :os.cmd('gzip --stdout #{path} > #{path}.gz') # `gzip` in Amazon Linux (version 1.5 as of 2018/01) does not have "--keep" option
          common_args ++ ["--body", "#{path}.gz", "--content-encoding", "gzip"]
        else
          common_args ++ ["--body", path]
        end
      _etag_json = request_to_s3api("put-object", args)
      if gzip? do
        File.rm!("#{path}.gz")
      end
      :ok
    end

    @impl true
    defun delete(key :: v[String.t]) :: :ok do
      request_to_s3api("delete-object", ["--key", key])
      :ok
    end

    defunp request_to_s3api(command :: v[String.t], args :: v[[String.t]]) :: map do
      {output, 0} = System.cmd("aws", ["s3api", command, "--bucket", @bucket_name | args])
      case output do
        ""   -> %{} # If no result found for the command, aws-cli returns empty string instead of JSON with empty content.
        json -> Poison.decode!(json)
      end
    end
  end
end
