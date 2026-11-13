defmodule TraysSocial.ErrorReports.Filter do
  @moduledoc """
  D120: strips secrets and personal data from an ErrorTracker context before
  it is stored. Wired in config.exs as `config :error_tracker, filter: ...`;
  ErrorTracker calls `sanitize/1` inside `ErrorTracker.report/3`, before the
  occurrence is written, so a redacted value never reaches the database.

  What it does:

    * Replaces the value of any sensitive key with `"[REDACTED]"`, at any
      depth, in maps and lists, whether the key is a string or an atom and
      whatever its case. A key is sensitive when it is in `@sensitive_keys`,
      contains one of `@sensitive_fragments` (so `user[password]`,
      `current_password` and `refresh_token` all match), or
      is listed in `:phoenix, :filter_parameters`.
    * Drops the Authorization, Cookie and Set-Cookie headers from
      `"request.headers"` entirely, and redacts the token segment of a token
      route quoted in any other header value (a Referer sent from the
      password-reset page, say).
    * Redacts sensitive pairs inside the raw `"request.query"` string, and the
      token segment of the routes that carry one in the path (email
      confirmation, magic-link log-in, email change, password reset, device
      unregister).

  It never logs what it removes.
  """
  @behaviour ErrorTracker.Filter

  @redacted "[REDACTED]"

  @sensitive_keys ~w(jws signedpayload signedtransactioninfo signedrenewalinfo
                     signed_transaction identity_token authorization_code api_key apikey
                     authorization cookie set-cookie email recipient)
  @sensitive_fragments ~w(password token secret)

  @dropped_headers ~w(authorization cookie set-cookie)

  # Routes whose last path segment is a bearer token (see router.ex).
  @token_path_prefixes ~w(/users/confirm/ /users/log-in/ /users/settings/confirm-email/
                          /users/reset-password/ /api/v1/devices/)

  @impl true
  def sanitize(context) when is_map(context) do
    context
    |> drop_headers()
    |> redact_query()
    |> redact_path()
    |> redact(phoenix_filter_keys())
  end

  def sanitize(context), do: context

  defp drop_headers(context) do
    case fetch(context, "request.headers") do
      {key, headers} when is_map(headers) ->
        kept =
          headers
          |> Map.reject(fn {name, _} -> normalize(name) in @dropped_headers end)
          |> Map.new(fn {name, value} -> {name, redact_token_urls(value)} end)

        Map.put(context, key, kept)

      _ ->
        context
    end
  end

  defp redact_query(context) do
    case fetch(context, "request.query") do
      {key, query} when is_binary(query) and query != "" ->
        Map.put(context, key, redact_query_string(query))

      _ ->
        context
    end
  end

  defp redact_query_string(query) do
    extra = phoenix_filter_keys()

    query
    |> String.split("&")
    |> Enum.map_join("&", fn pair ->
      case String.split(pair, "=", parts: 2) do
        [name, _value] ->
          if sensitive_query_name?(URI.decode_www_form(name), extra),
            do: name <> "=" <> @redacted,
            else: pair

        _ ->
          pair
      end
    end)
  end

  # `user[email]` is sensitive when the outer name or any bracketed segment is.
  defp sensitive_query_name?(name, extra) do
    segments = for [_, segment] <- Regex.scan(~r/\[([^\]]*)\]/, name), do: segment
    Enum.any?([name | segments], &sensitive?(&1, extra))
  end

  defp redact_path(context) do
    case fetch(context, "request.path") do
      {key, path} when is_binary(path) ->
        Map.put(context, key, redact_token_path(path))

      _ ->
        context
    end
  end

  defp redact_token_path(path) do
    case Enum.find(@token_path_prefixes, &String.starts_with?(path, &1)) do
      nil -> path
      prefix -> prefix <> @redacted
    end
  end

  # W254: a header such as Referer can carry a token route as a full URL
  # (https://host/users/reset-password/<token>), so redact the segment
  # after any token prefix wherever it appears in the value.
  defp redact_token_urls(value) when is_binary(value) do
    Enum.reduce(@token_path_prefixes, value, fn prefix, acc ->
      String.replace(acc, ~r/#{Regex.escape(prefix)}[^?#\s]+/, prefix <> @redacted)
    end)
  end

  defp redact_token_urls(value), do: value

  defp redact(map, extra) when is_map(map) and not is_struct(map) do
    Map.new(map, fn {key, value} ->
      if sensitive?(key, extra), do: {key, @redacted}, else: {key, redact(value, extra)}
    end)
  end

  defp redact(list, extra) when is_list(list), do: Enum.map(list, &redact(&1, extra))
  defp redact(value, _extra), do: value

  defp sensitive?(key, extra) when is_atom(key) or is_binary(key) do
    name = normalize(key)

    name in @sensitive_keys or name in extra or
      Enum.any?(@sensitive_fragments, &String.contains?(name, &1))
  end

  defp sensitive?(_key, _extra), do: false

  defp normalize(key) when is_atom(key), do: key |> Atom.to_string() |> String.downcase()
  defp normalize(key) when is_binary(key), do: String.downcase(key)
  defp normalize(_key), do: ""

  # Context keys arrive as strings from the Plug/Phoenix integrations; a
  # manual report may use atoms.
  defp fetch(context, name) do
    Enum.find_value(context, :error, fn {key, value} ->
      if (is_binary(key) or is_atom(key)) and to_string(key) == name, do: {key, value}
    end)
  end

  defp phoenix_filter_keys do
    case Application.get_env(:phoenix, :filter_parameters, ["password"]) do
      {:discard, keys} when is_list(keys) -> Enum.map(keys, &normalize/1)
      keys when is_list(keys) -> Enum.map(keys, &normalize/1)
      _ -> []
    end
  end
end
