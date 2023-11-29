defmodule AntikytheraAws.ImdsTest do
  use Croma.TestCase
  alias Antikythera.Httpc

  @imds_endpoint "http://169.254.169.254"
  @imds_token_path "/latest/api/token"

  describe "get/1" do
    test "should get a token and use it in the request" do
      fake_token = "fake-token"

      :meck.expect(Httpc, :put, fn url, _body, _header ->
        assert url == @imds_endpoint <> @imds_token_path

        {:ok,
         %Httpc.Response{
           status: 200,
           body: fake_token,
           headers: %{},
           cookies: %{}
         }}
      end)

      :meck.expect(Httpc, :get, fn _url, header ->
        assert Map.get(header, "X-aws-ec2-metadata-token") == fake_token

        {:ok,
         %Httpc.Response{
           status: 200,
           body: "",
           headers: %{},
           cookies: %{}
         }}
      end)

      Imds.get("dummy")
    end

    test "should request to imds_endpoint" do
      test_path = "/latest/meta-data/placement/availability-zone"

      :meck.expect(Httpc, :put, fn _url, _body, _header ->
        {:ok,
         %Httpc.Response{
           status: 200,
           body: "fake-token",
           headers: %{},
           cookies: %{}
         }}
      end)

      :meck.expect(Httpc, :get, fn url, _header ->
        assert url == @imds_endpoint <> test_path

        {:ok,
         %Httpc.Response{
           status: 200,
           body: "",
           headers: %{},
           cookies: %{}
         }}
      end)

      Imds.get(test_path)
    end

    test "should return :ok response from Httpc.get/2" do
      ok_response =
        {:ok,
         %Httpc.Response{
           status: 200,
           body: "IMDS response",
           headers: %{},
           cookies: %{}
         }}

      :meck.expect(Httpc, :put, fn _url, _body, _header ->
        {:ok,
         %Httpc.Response{
           status: 200,
           body: "fake-token",
           headers: %{},
           cookies: %{}
         }}
      end)

      :meck.expect(Httpc, :get, fn _url, _header ->
        ok_response
      end)

      assert Imds.get("fake") == ok_response
    end

    test "should return :error response from Httpc.get/2" do
      error_response = {:error, "error"}

      :meck.expect(Httpc, :put, fn _url, _body, _header ->
        {:ok,
         %Httpc.Response{
           status: 200,
           body: "fake-token",
           headers: %{},
           cookies: %{}
         }}
      end)

      :meck.expect(Httpc, :get, fn _url, _header ->
        error_response
      end)

      assert Imds.get("fake") == error_response
    end
  end

  describe "get!/1" do
    test "should return Response if Httpc.get/2 returns :ok" do
      test_response = %Httpc.Response{
        status: 200,
        body: "IMDS response",
        headers: %{},
        cookies: %{}
      }

      :meck.expect(Httpc, :put, fn _url, _body, _header ->
        {:ok,
         %Httpc.Response{
           status: 200,
           body: "fake-token",
           headers: %{},
           cookies: %{}
         }}
      end)

      :meck.expect(Httpc, :get, fn _url, _header ->
        {:ok, test_response}
      end)

      assert Imds.get!("fake") == test_response
    end

    test "should raise ArgumentError if Httpc.get/2 returns :error" do
      test_response = %Httpc.Response{
        status: 200,
        body: "IMDS response",
        headers: %{},
        cookies: %{}
      }

      :meck.expect(Httpc, :put, fn _url, _body, _header ->
        {:ok,
         %Httpc.Response{
           status: 200,
           body: "fake-token",
           headers: %{},
           cookies: %{}
         }}
      end)

      :meck.expect(Httpc, :get, fn _url, _header ->
        {:error, test_response}
      end)

      assert_raise ArgumentError, fn ->
        Imds.get!("fake")
      end
    end
  end
end
