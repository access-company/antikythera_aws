# Copyright(c) 2015-2018 ACCESS CO., LTD. All rights reserved.

defmodule AntikytheraAws.Auth.InstanceProfileCredentialsTest do
  use Croma.TestCase
  alias Antikythera.{Time, Httpc}
  alias Antikythera.Httpc.Response, as: Res
  alias AntikytheraCore.Ets.SystemCache
  alias AntikytheraAws.Auth.Credentials, as: Creds

  @valid_credentials      %Creds{access_key_id: "aws_access_key_id", secret_access_key: "aws_secret_access_key",
                                 security_token: "token", source_type: :instance}
  @role_endpoint          "http://169.254.169.254/latest/meta-data/iam/security-credentials/"
  @test_role              "test_role"
  @creds_endpoint         @role_endpoint <> @test_role
  @creds_endpoint_success {:ok, %Res{body: ~S({"Code"  : "Success", "LastUpdated" : "2016-01-01T00:00:00Z",
                                               "Token" : "token",   "Expiration"  : "2099-12-31T23:59:59Z",
                                               "Type"  : "AWS-HMAC","AccessKeyId" : "aws_access_key_id",
                                               "SecretAccessKey" : "aws_secret_access_key"}),
                                     headers: %{}, status: 200}}
  @system_cache_key       :aws_auth_instance_profile_credentials_cache

  defp creds_endpoint_expect(res) do
    :meck.expect(Httpc, :get, fn
      @role_endpoint  -> {:ok, %Res{body: @test_role, headers: %{}, status: 200}}
      @creds_endpoint -> if is_function(res), do: res.(), else: res
      other           -> :meck.passthrough([other])
    end)
  end

  setup do
    :meck.new(Httpc, [:passthrough])
    on_exit fn ->
      :meck.unload()
      :ets.delete(SystemCache.table_name(), @system_cache_key)
    end
  end

  test "should get and cache Credentials from instance metadata API (if not already cached)" do
    assert :ets.lookup(SystemCache.table_name(), @system_cache_key) == []
    creds_endpoint_expect(@creds_endpoint_success)
    assert InstanceProfileCredentials.credentials() == @valid_credentials
    [{_key, %{credentials: cached_creds, expiration: expiration}}] = :ets.lookup(SystemCache.table_name(), @system_cache_key)
    assert cached_creds == @valid_credentials
    assert expiration == {Time, {2099, 12, 31}, {23, 59, 59}, 0}
  end

  test "should use cached Credentials if not expired" do
    time = Time.now() |> Time.shift_hours(1) # expires in 60mins
    active_credentials = %Creds{@valid_credentials | access_key_id: "not_expired", secret_access_key: "not_expired"}
    active_credentials_cache = %{credentials: active_credentials, expiration: time}
    :ets.insert(SystemCache.table_name(), {@system_cache_key, active_credentials_cache})
    assert InstanceProfileCredentials.credentials() == active_credentials
  end

  test "should refresh cached Credentials if expired" do
    time = Time.now() |> Time.shift_minutes(-10) # expired 10mins ago
    expired_credentials = %Creds{@valid_credentials | access_key_id: "expired", secret_access_key: "expired"}
    expired_credentials_cache = %{credentials: expired_credentials, expiration: time}
    :ets.insert(SystemCache.table_name(), {@system_cache_key, expired_credentials_cache})
    creds_endpoint_expect(@creds_endpoint_success)
    assert InstanceProfileCredentials.credentials() == @valid_credentials
  end

  test "should refresh cached Credentials if expiring soon" do
    time = Time.now() |> Time.shift_minutes(2) # expires in 2mins
    expiring_credentials = %Creds{@valid_credentials | access_key_id: "expiring", secret_access_key: "expiring"}
    expiring_credentials_cache = %{credentials: expiring_credentials, expiration: time}
    :ets.insert(SystemCache.table_name(), {@system_cache_key, expiring_credentials_cache})
    creds_endpoint_expect(@creds_endpoint_success)
    assert InstanceProfileCredentials.credentials() == @valid_credentials
  end

  test "should retry getting Credentials on instance metadata API timeout" do
    redefine_and_error = fn ->
      creds_endpoint_expect(@creds_endpoint_success) # redefine meck on 1st call, so that it returns success on 2nd call
      {:error, :timeout}
    end
    creds_endpoint_expect(redefine_and_error)
    assert InstanceProfileCredentials.credentials() == @valid_credentials
  end

  test "should result in nil if instance metadata API does not respond successfully" do
    creds_endpoint_expect({:error, :timeout})
    assert InstanceProfileCredentials.credentials() == nil
  end
end
