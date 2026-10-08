defmodule TraysSocialWeb.API.V1.FeatureController do
  @moduledoc """
  `GET /api/v1/features` -- the server-controlled client flags
  (`TraysSocial.Features.client_flags/0`). Lives in the authenticated read
  scope, so an unauthenticated request gets 401 from the api_auth pipeline.
  """
  use TraysSocialWeb, :controller

  alias TraysSocial.Features

  def index(conn, _params) do
    json(conn, %{data: Features.client_flags()})
  end
end
