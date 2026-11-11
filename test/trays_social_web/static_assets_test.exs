defmodule TraysSocialWeb.StaticAssetsTest do
  # W238: brand assets in priv/static. Plug.Static serves `<file>.gz` to
  # gzip-capable clients whenever it exists, so a tracked .gz that lags its
  # source keeps serving the old asset in production.
  use ExUnit.Case, async: true

  @static Path.expand("../../priv/static", __DIR__)
  @design Path.expand("../../docs/design", __DIR__)

  test "logo.svg is the C Handles mark from docs/design" do
    assert File.read!(Path.join(@static, "images/logo.svg")) ==
             File.read!(Path.join(@design, "trays-logo-handles.svg"))
  end

  test "logo.svg.gz decompresses to the current logo.svg" do
    gz = File.read!(Path.join(@static, "images/logo.svg.gz"))
    assert :zlib.gunzip(gz) == File.read!(Path.join(@static, "images/logo.svg"))
  end

  test "the favicon and apple-touch-icon that the root layout links are present" do
    assert File.regular?(Path.join(@static, "favicon.ico"))
    assert File.regular?(Path.join(@static, "apple-touch-icon.png"))
  end
end
