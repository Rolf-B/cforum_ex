defmodule CforumWeb.Plug.CurrentUser do
  @moduledoc """
  This plug is plugged in the browser pipeline and loads and assigns the
  current user
  """

  alias Cforum.Accounts.Users

  def init(opts), do: opts

  def call(conn, _opts) do
    uid = Plug.Conn.get_session(conn, :user_id)
    current_user = if uid != nil, do: Cforum.Accounts.Users.get_user(uid), else: nil

    conn
    |> Plug.Conn.assign(:current_user, current_user)
    |> Plug.Conn.assign(:is_moderator, Users.moderator?(current_user))
    |> put_user_token(current_user)
  end

  defp put_user_token(conn, nil), do: conn

  defp put_user_token(conn, current_user) do
    token = Phoenix.Token.sign(conn, "user socket", current_user.user_id)
    Plug.Conn.assign(conn, :user_token, token)
  end
end
