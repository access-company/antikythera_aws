# Copyright(c) 2015-2021 ACCESS CO., LTD. All rights reserved.

use Croma

defmodule AntikytheraAws.Auth do
  @moduledoc """
  Provides a method to get AWS Access Key (access key ID, secret access key, and security token).
  """

  defmodule SourceType do
    use Croma.SubtypeOfAtom, values: [:instance], default: :instance
  end

  defmodule Credentials do
    use Croma.Struct,
      recursive_new?: true,
      fields: [
        access_key_id: Croma.String,
        secret_access_key: Croma.String,
        source_type: SourceType,
        security_token: Croma.TypeGen.nilable(Croma.String)
      ]
  end

  defmodule InstanceProfileCredentials do
    alias Antikythera.{Time, Httpc}
    alias Antikythera.Httpc.Response, as: Res
    alias AntikytheraCore.Ets.SystemCache

    @credentials_endpoint "http://169.254.169.254/latest/meta-data/iam/security-credentials/"
    @system_cache_key :aws_auth_instance_profile_credentials_cache
    @default_try_count 2
    @refresh_timing -180_000

    defun credentials() :: nil | Credentials.t() do
      case :ets.lookup(SystemCache.table_name(), @system_cache_key) do
        [{@system_cache_key, cached_credentials}] ->
          refresh_if_near_expiration(cached_credentials)

        [] ->
          get_credentials_with_aws_iam()
      end
    end

    defp refresh_if_near_expiration(cached_credentials) do
      check_time = cached_credentials.expiration |> Time.shift_milliseconds(@refresh_timing)

      if check_time > Time.now() do
        cached_credentials.credentials
      else
        get_credentials_with_aws_iam()
      end
    end

    defp get_credentials_with_aws_iam(try_count \\ @default_try_count) do
      if try_count > 0 do
        case send_credentials_request() do
          {:ok, response_credentials} -> store_credentials(response_credentials)
          {:error, _} -> get_credentials_with_aws_iam(try_count - 1)
        end
      else
        nil
      end
    end

    defp send_credentials_request() do
      Croma.Result.m do
        %Res{body: role_name} <- Httpc.get(@credentials_endpoint)
        %Res{body: creds} <- Httpc.get(@credentials_endpoint <> role_name)
        Poison.decode(creds)
      end
    end

    defp store_credentials(%{
           "AccessKeyId" => access_key_id,
           "SecretAccessKey" => secret_key,
           "Expiration" => expiration_str,
           "Token" => token
         }) do
      security_credentials = %Credentials{
        source_type: :instance,
        access_key_id: access_key_id,
        secret_access_key: secret_key,
        security_token: token
      }

      {:ok, expiration} = Time.from_iso_timestamp(expiration_str)
      cache_map = %{credentials: security_credentials, expiration: expiration}
      :ets.insert(SystemCache.table_name(), {@system_cache_key, cache_map})
      security_credentials
    end
  end
end
