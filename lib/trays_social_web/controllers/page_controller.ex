defmodule TraysSocialWeb.PageController do
  use TraysSocialWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
