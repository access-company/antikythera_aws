# Copyright(c) 2015-2018 ACCESS CO., LTD. All rights reserved.

defmodule AntikytheraAws.Signer.V4Test do
  use Croma.TestCase
  alias AntikytheraAws.Auth.Credentials, as: Creds

  @example_id      "AKIDEXAMPLE"
  @example_secret  "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY"
  @example_creds   %Creds{access_key_id: @example_id, secret_access_key: @example_secret}
  @example_region  "us-east-1"
  @example_payload "example payload"

  defp hex_sha256(str), do: Base.encode16(:crypto.hash(:sha256, str), case: :lower)

  test "canonical_uri/1 should normalize path as per AWS specification" do
    [
      {"/"              , "/"                      },
      {"/azAZ09.-_~"    , "/azAZ09.-_~"            }, # RFC3986 "Unreserved"
      {"/*:( )"         , "/%2A%3A%28%20%29"       }, # RFC3986 "Reserved"
      {"/path-*"        , "/path-%2A"              },
      {"/(seg1)/(seg2)/", "/%28seg1%29/%28seg2%29/"},
      {"/escaped%2Fchar", "/escaped%252Fchar"      },
    ] |> Enum.each(fn {path, expected} ->
      assert V4.canonical_uri(path) == expected
    end)
  end

  test "canonical_query_string/1 should normalize query string as per AWS specification" do
    [
      {[]                                  , ""                           },
      {[{"k", "v"}, {"K", "V"}, {"k", "a"}], "K=V&k=a&k=v"                }, # Sorted with key, ascending order (value order does not matter)
      {[{"wc", "*"}, {"colon(num)", "1:2"}], "colon%28num%29=1%3A2&wc=%2A"},
    ] |> Enum.each(fn {params, expected} ->
      assert V4.canonical_query_string(params) == expected
    end)
  end

  test "canonical_headers_string/1 should normalize headers as per AWS specification" do
    [
      {%{"host" => "example.com", "content-type" => "application/json"}, "content-type:application/json\nhost:example.com\n"},
      {%{"host" => "example.com", "x-amz-date" => "20160101T000000Z"}  , "host:example.com\nx-amz-date:20160101T000000Z\n"  },
      {%{"host" => "example.com", "my-header" => " White   Spaces    "}, "host:example.com\nmy-header:White Spaces\n"       },
    ] |> Enum.each(fn {headers, expected} ->
      assert V4.canonical_headers_string(headers) == expected
    end)
  end

  test "signed_headers_string/1 should list header keys as per AWS specification" do
    [
      {%{"host" => "example.com", "content-type" => "application/json"}, "content-type;host"},
      {%{"host" => "example.com", "x-amz-date" => "20160101T000000Z"}  , "host;x-amz-date"  },
      {%{"host" => "example.com", "my-header" => " White   Spaces    "}, "host;my-header"   },
      {%{"host" => "example.com", "h1" => "v1", "a2" => "v2"}          , "a2;h1;host"       },
    ] |> Enum.each(fn {headers, expected} ->
      assert V4.signed_headers_string(headers) == expected
    end)
  end

  # Example from: http://docs.aws.amazon.com/general/latest/gr/sigv4-calculate-signature.html
  test "signing_key/4 should derive signing key" do
    expected_key = <<196, 175, 177, 204, 87, 113, 216, 113, 118, 58, 57, 62, 68, 183, 3, 87, 27, 85, 204, 40, 66, 77, 26, 94, 134, 218, 110, 211, 193, 84, 164, 185>>
    assert V4.signing_key(@example_secret, "20150830T123600Z", @example_region, "iam") == expected_key
  end

  # Example from: http://docs.aws.amazon.com/general/latest/gr/sigv4-add-signature-to-request.html
  test "prepare_headers/8 should produce signed headers" do
    expected_auth_value = "AWS4-HMAC-SHA256 Credential=#{@example_id}/20150830/#{@example_region}/iam/aws4_request, SignedHeaders=content-type;host;x-amz-date, Signature=5d672d79c15b13162d9279b0855cfba6789a8edb4c82c400e06b5924a6f2b5d7"
    headers = %{"Host" => "iam.amazonaws.com", "X-Amz-Date" => "20150830T123600Z", "Content-Type" => "application/x-www-form-urlencoded; charset=utf-8"}
    params = [{"Action", "ListUsers"}, {"Version", "2010-05-08"}]
    result = V4.prepare_headers(@example_creds, @example_region, "iam", :get, "/", "", headers, params)
    assert result["x-amz-date"] == "20150830T123600Z"
    assert result["x-amz-security-token"] == nil
    assert result["authorization"] == expected_auth_value
  end

  # Example from http://docs.aws.amazon.com/general/latest/gr/signature-v4-test-suite.html
  test "prepare_headers/8 should correctly produce signed headers for test suite examples" do
    # get-vanilla-query-order-key-case.req
    h1 = %{"Date" => "Mon, 09 Sep 2011 23:36:00 GMT", "Host" => "host.foo.com"}
    p1 = [{"foo", "Zoo"}, {"foo", "aha"}]
    r1 = V4.prepare_headers(@example_creds, @example_region, "host", :get, "/", "", h1, p1)
    assert r1["authorization"] == "AWS4-HMAC-SHA256 Credential=#{@example_id}/20110909/#{@example_region}/host/aws4_request, SignedHeaders=date;host, Signature=be7148d34ebccdc6423b19085378aa0bee970bdc61d144bd1a8c48c33079ab09"

    # get-vanilla-ut8-query.req
    h2 = %{"Date" => "Mon, 09 Sep 2011 23:36:00 GMT", "Host" => "host.foo.com"}
    p2 = [{"ሴ", "bar"}]
    r2 = V4.prepare_headers(@example_creds, @example_region, "host", :get, "/", "", h2, p2)
    assert r2["authorization"] == "AWS4-HMAC-SHA256 Credential=#{@example_id}/20110909/#{@example_region}/host/aws4_request, SignedHeaders=date;host, Signature=6fb359e9a05394cc7074e0feb42573a2601abc0c869a953e8c5c12e4e01f1a8c"

    # post-vanilla-query-nonunreserved.req
    # Original example query string is,
    #
    #     @#$%^&+=/,?><`";:\|][{} =@#$%^&+=/,?><`";:\|][{}
    #
    # and the example for canonical request states this should be interpreted as assertion below.
    # It expects `+` in query string part was ` ` on requester side,
    # but in signature, expects to be encoded as `%20`.
    # This conforms with URI-spec from W3C, (https://www.w3.org/Addressing/URL/uri-spec.html)
    # where `+` is OK as replacement for ` ` in query string only, instead of proper `%20`.
    # Unescaped ` ` indicates end of URL, thus the string afterward will be ignored.
    h3 = %{"Date" => "Mon, 09 Sep 2011 23:36:00 GMT", "Host" => "host.foo.com"}
    p3 = [{"@#$%^", ""}, {" ", ~S(/,?><`";:\|][{})}]
    assert V4.canonical_query_string(p3) == "%20=%2F%2C%3F%3E%3C%60%22%3B%3A%5C%7C%5D%5B%7B%7D&%40%23%24%25%5E="
    r3 = V4.prepare_headers(@example_creds, @example_region, "host", :post, "/", "", h3, p3)
    assert r3["authorization"] == "AWS4-HMAC-SHA256 Credential=#{@example_id}/20110909/#{@example_region}/host/aws4_request, SignedHeaders=date;host, Signature=28675d93ac1d686ab9988d6617661da4dffe7ba848a2285cb75eac6512e861f9"

    # post-x-www-form-urlencoded-parameters.req
    h4 = %{"Content-Type" => "application/x-www-form-urlencoded; charset=utf8", "Date" => "Mon, 09 Sep 2011 23:36:00 GMT", "Host" => "host.foo.com"}
    p4 = []
    r4 = V4.prepare_headers(@example_creds, @example_region, "host", :post, "/", "foo=bar", h4, p4)
    assert r4["authorization"] == "AWS4-HMAC-SHA256 Credential=#{@example_id}/20110909/#{@example_region}/host/aws4_request, SignedHeaders=content-type;date;host, Signature=b105eb10c6d318d2294de9d49dd8b031b55e3c3fe139f2e637da70511e9e7b71"
  end

  test "prepare_headers/8 should raise if 'host' header missing" do
    catch_error V4.prepare_headers(@example_creds, @example_region, "iam", :get, "/", "", %{}, [])
  end

  test "prepare_headers/8 should generate 'x-amz-date' header if no date headers provided" do
    result = V4.prepare_headers(@example_creds, @example_region, "iam", :get, "/", "", %{"host" => "example.com"}, [])
    assert Map.has_key?(result, "x-amz-date")
  end

  test "prepare_headers/8 should put 'x-amz-security-token' if security_token present" do
    creds = %Creds{@example_creds | security_token: "token"}
    result = V4.prepare_headers(creds, @example_region, "iam", :get, "/", "", %{"host" => "example.com"}, [])
    assert Map.has_key?(result, "x-amz-date")
    assert result["x-amz-security-token"] == creds.security_token
    sheaders_str = ~r/SignedHeaders=host;x-amz-date;x-amz-security-token, /
    assert result["authorization"] |> String.match?(sheaders_str)
  end

  test "prepare_headers/8 should raise if `path` includes query string part" do
    path_with_qs = "/hoge?foo=bar"
    catch_error V4.prepare_headers(@example_creds, @example_region, "iam", :get, path_with_qs, "", %{"host" => "example.com"}, [{"foo", "bar"}])
  end

  test "prepare_headers/8 should generate 'x-amz-content-sha256' if service is S3" do
    result = V4.prepare_headers(@example_creds, @example_region, "s3", :put, "/object_key", @example_payload, %{"host" => "example.com"}, [])
    assert result["x-amz-content-sha256"] == hex_sha256(@example_payload)
  end

  test "prepare_headers/8 should generate 'x-amz-content-sha256' of an empty string if service is S3 and no payload" do
    result = V4.prepare_headers(@example_creds, @example_region, "s3", :get, "/object_key", "", %{"host" => "example.com"}, [])
    assert result["x-amz-content-sha256"] == hex_sha256("")
  end

  test "prepare_headers/8 should not generate 'x-amz-content-sha256' if service is not S3" do
    result = V4.prepare_headers(@example_creds, @example_region, "iam", :put, "/object_key", @example_payload, %{"host" => "example.com"}, [])
    refute Map.has_key?(result, "x-amz-content-sha256")
  end
end
