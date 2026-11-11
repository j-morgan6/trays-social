defmodule TraysSocialWeb.StaticAssetsTest do
  # W238: brand assets in priv/static. Plug.Static serves `<file>.gz` to
  # gzip-capable clients whenever it exists, so a tracked .gz that lags its
  # source keeps serving the old asset in production.
  use ExUnit.Case, async: true

  @static Path.expand("../../priv/static", __DIR__)
  @design Path.expand("../../docs/design", __DIR__)

  defp static(path), do: @static |> Path.join(path) |> File.read!()
  defp design(path), do: @design |> Path.join(path) |> File.read!()
  defp static_file?(path), do: @static |> Path.join(path) |> File.regular?()

  test "logo.svg is the C Handles mark from docs/design" do
    assert static("images/logo.svg") == design("trays-logo-handles.svg")
  end

  test "logo.svg.gz decompresses to the current logo.svg" do
    assert "images/logo.svg.gz" |> static() |> :zlib.gunzip() == static("images/logo.svg")
  end

  test "logo-on-dark.svg is the on-dark C Handles mark from docs/design" do
    assert static("images/logo-on-dark.svg") == design("trays-logo-handles-on-dark.svg")
  end

  test "logo-on-dark.svg.gz decompresses to the current logo-on-dark.svg" do
    assert "images/logo-on-dark.svg.gz" |> static() |> :zlib.gunzip() ==
             static("images/logo-on-dark.svg")
  end

  # W240: Nunito is self-hosted because the CSP only allows fonts from 'self'.
  test "the self-hosted Nunito font is a real woff2 and ships with its OFL licence" do
    assert <<"wOF2", _::binary>> = static("fonts/nunito-latin-wght-normal.woff2")
    assert static("fonts/OFL-Nunito.txt") =~ "SIL OPEN FONT LICENSE Version 1.1"
  end

  test "the favicon and apple-touch-icon that the root layout links are present" do
    assert static_file?("favicon.ico")
    assert static_file?("apple-touch-icon.png")
  end
end
