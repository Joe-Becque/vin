defmodule VinWeb.PageController do
  use VinWeb, :controller

  def index(conn, _params) do
    # render(conn, "index.html")
    redirect(conn, to: "/api/graphiql")
  end
end
