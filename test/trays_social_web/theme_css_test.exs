defmodule TraysSocialWeb.ThemeCssTest do
  # W240: the redesign tokens switch by data-theme AND by the OS preference
  # (the "system" setting removes data-theme). app.css repeats the dark token
  # set under both selectors; this keeps the two copies identical.
  use ExUnit.Case, async: true

  @css Path.expand("../../assets/css/app.css", __DIR__)

  defp block_after(css, marker) do
    [_, rest] = String.split(css, marker, parts: 2)
    [body | _] = String.split(rest, "}", parts: 2)
    body
  end

  defp tokens(body) do
    ~r/(--tr-[a-z-]+):\s*([^;]+);/
    |> Regex.scan(body, capture: :all_but_first)
    |> Map.new(fn [name, value] -> {name, String.trim(value)} end)
  end

  test "the data-theme dark and prefers-color-scheme dark token sets are identical" do
    css = File.read!(@css)
    by_attribute = css |> block_after(~s([data-theme="dark"] {)) |> tokens()
    by_media = css |> block_after(~s|:root:not([data-theme="light"]) {|) |> tokens()

    assert map_size(by_attribute) >= 10
    assert by_attribute == by_media
  end

  test "the logo swaps to the on-dark mark under both dark selectors" do
    css = File.read!(@css)
    assert css =~ ~s([data-theme="dark"] .logo-on-dark)
    assert css =~ ~s|:root:not([data-theme="light"]) .logo-on-dark|
  end
end
