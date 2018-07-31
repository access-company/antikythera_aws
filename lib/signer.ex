# Copyright(c) 2015-2018 ACCESS CO., LTD. All rights reserved.

use Croma

defmodule AntikytheraAws.Signer do
  @moduledoc """
  Provides request signing for AWS APIs.
  """

  alias Antikythera.Time
  alias Antikythera.IsoTimestamp.Basic, as: AmzDate
  alias Antikythera.UnencodedPath, as: UPath
  alias Antikythera.EncodedPath, as: EPath
  alias Antikythera.Http.{Headers, Method}
  alias AntikytheraAws.Auth.Credentials, as: Creds

  defmodule V4 do
    @moduledoc """
    Signing with [Signature Version 4](http://docs.aws.amazon.com/general/latest/gr/sigv4_signing.html).
    """

    @key_prefix         "AWS4"
    @sign_algorithm     "AWS4-HMAC-SHA256"
    @termination_string "aws4_request"

    @doc """
    From given `creds` and request informations, returns headers ready for AWS request.

    Arguments are mostly `Antikythera.Httpc.request/5` compatible, with some extra treatments:

    - `creds`, `region`, `service` must be supplied
        - `creds` are basically retrieved with `AntikytheraAws.Auth.InstanceProfileCredentials`
    - `path` must not include query string. Relative/redundant path must be resolved beforehand
        - Any characters in segments except RFC3986 "Unreserved Characters", will be encoded
        - Escape chars ("%") in segments will be encoded to "%25"
    - `payload` serialization must be done beforehand, since it will be hashed in signature and compared on AWS
    - `headers` must have "host" field, which is a hard-requirement for signature
        - "x-amz-date" or "date" field value will be used as signature date. "x-amz-date" will be prioritized
        - If neither exist, "x-amz-date" will be generated with current date
    - `params` must be decoded query strings, in a list of tuple-2
        - To convert from `Antikythera.Http.QueryParams` (which is `Croma.SubtypeOfMap`), just use `Map.to_list/1`
    """
    defun prepare_headers(%Creds{access_key_id: aki, secret_access_key: sak, security_token: st} = _creds,
                          region  :: v[String.t],
                          service :: v[String.t],
                          method  :: v[Method.t],
                          path    :: v[UPath.t],
                          payload :: v[binary],
                          headers :: v[Headers.t],
                          params  :: [{String.t, String.t}]) :: Headers.t do
      if String.contains?(path, "?"), do: raise("`path` must not include query string part!")
      payload_sha256                 = hex_sha256(payload)
      {sign_ready_headers, amz_date} = canonicalize_headers_with_amz_date(headers, st, service, payload_sha256)
      signed_headers_str             = signed_headers_string(sign_ready_headers) # Declare headers used for signing (AWS will ignore other headers for signature verification)
      canonical_request              = make_canonical_request(sign_ready_headers, signed_headers_str, method, path, payload_sha256, params)
      signature                      = compute_signature(aki, sak, amz_date, region, service, canonical_request, signed_headers_str)
      Map.put(sign_ready_headers, "authorization", signature)
    end

    defunp canonicalize_headers_with_amz_date(headers        :: v[Headers.t],
                                              security_token :: v[nil | String.t],
                                              service        :: v[String.t],
                                              payload_sha256 :: v[String.t]) :: {Headers.t, AmzDate.t} do
      downcased_headers = Map.new(headers, fn {key, val} -> {String.downcase(key), val} end)
      if !Map.has_key?(downcased_headers, "host"), do: raise("'host' header is required!")
      {amz_date, headers1} = gen_amz_date_with_added_headers(downcased_headers)
      headers2             = if security_token , do: Map.put(headers1, "x-amz-security-token", security_token), else: headers1
      sign_ready_headers   = if service == "s3", do: Map.put(headers2, "x-amz-content-sha256", payload_sha256), else: headers2
      {sign_ready_headers, amz_date}
    end

    defunp gen_amz_date_with_added_headers(headers :: v[Headers.t]) :: {AmzDate.t, Headers.t} do
      case headers do
        %{"x-amz-date" => ad} -> {ad, headers}
        %{"date" => date}     ->
          ad = Time.from_http_date(date) |> Croma.Result.get!() |> Time.to_iso_basic()
          {ad, headers}
        without_amz_date      ->
          ad = Time.to_iso_basic(Time.now())
          {ad, Map.put(without_amz_date, "x-amz-date", ad)}
      end
    end

    defunpt signed_headers_string(downcased_headers :: v[Headers.t]) :: String.t do
      Map.keys(downcased_headers)
      |> Enum.sort()
      |> Enum.join(";")
    end

    defunp make_canonical_request(sign_ready_headers :: v[Headers.t],
                                  signed_headers_str :: v[String.t],
                                  method             :: v[Method.t],
                                  path               :: v[UPath.t],
                                  payload_sha256     :: v[String.t],
                                  params             :: [{String.t, String.t}]) :: String.t do
      uppercase_method = Method.to_string(method)
      [
        uppercase_method,
        canonical_uri(path),
        canonical_query_string(params),
        canonical_headers_string(sign_ready_headers),
        signed_headers_str,
        payload_sha256,
      ] |> Enum.join("\n")
    end

    defunpt canonical_uri(path :: v[UPath.t]) :: EPath.t do
      path
      |> String.split("/")
      |> Enum.map_join("/", &canonical_encode/1)
    end

    defunpt canonical_query_string(params :: [{String.t, String.t}]) :: String.t do
      Enum.map(params, fn {key, val} ->
        {canonical_encode(key), canonical_encode(val)}
      end)
      |> Enum.sort()
      |> Enum.map_join("&", fn {ckey, cval} -> "#{ckey}=#{cval}" end)
    end

    defunpt canonical_headers_string(downcased_headers :: v[Headers.t]) :: String.t do
      Enum.sort(downcased_headers)
      |> Enum.into("", fn {key, val} -> "#{key}:#{trimall(val)}\n" end) # Should end with trailing newline
    end

    defunp compute_signature(aki                :: v[String.t],
                             sak                :: v[String.t],
                             amz_date           :: v[AmzDate.t],
                             region             :: v[String.t],
                             service            :: v[String.t],
                             canonical_request  :: v[String.t],
                             signed_headers_str :: v[String.t]) :: String.t do
      skey  = signing_key(sak, amz_date, region, service)
      scope = credential_scope(amz_date, region, service)
      sts   = string_to_sign(amz_date, scope, canonical_request)
      sign  = hex_hmac_sha256(skey, sts)
      "#{@sign_algorithm} Credential=#{aki}/#{scope}, SignedHeaders=#{signed_headers_str}, Signature=#{sign}"
    end

    defunpt signing_key(sak      :: v[String.t],
                        amz_date :: v[AmzDate.t],
                        region   :: v[String.t],
                        service  :: v[String.t]) :: String.t do
      short_date = String.slice(amz_date, 0..7)
      @key_prefix <> sak
      |> hmac_sha256(short_date)
      |> hmac_sha256(region)
      |> hmac_sha256(service)
      |> hmac_sha256(@termination_string)
    end

    defunp credential_scope(amz_date :: v[AmzDate.t], region :: v[String.t], service :: v[String.t]) :: String.t do
      [String.slice(amz_date, 0..7), region, service, @termination_string] |> Enum.join("/")
    end

    defunpt string_to_sign(amz_date  :: v[AmzDate.t],
                           scope     :: v[String.t],
                           c_request :: v[String.t]) :: String.t do
      [@sign_algorithm, amz_date, scope, hex_sha256(c_request)] |> Enum.join("\n")
    end

    defpt hex_sha256(str),           do: Base.encode16(:crypto.hash(:sha256, str), case: :lower)
    defp  hmac_sha256(key, str),     do: :crypto.hmac(:sha256, key, str)
    defp  hex_hmac_sha256(key, str), do: Base.encode16(hmac_sha256(key, str), case: :lower)

    # Strip leading and trailing spaces and replace consecutive spaces to a single space
    defp trimall(str), do: String.trim(str) |> String.replace(~r/ +/, " ")

    defp canonical_encode(str), do: URI.encode(str, &URI.char_unreserved?/1)
  end
end
