defmodule Cforum.Abilities.Helpers do
  alias Cforum.Accounts.Groups
  alias Cforum.Accounts.Users

  alias Cforum.Accounts.ForumGroupPermission
  alias Cforum.Accounts.User
  alias Cforum.Accounts.Badge

  import Cforum.Helpers

  @doc """
  Returns true if a user is signed in, returns false otherwise

  ## Examples

      iex> signed_in?(conn)
      true
  """
  def signed_in?(conn), do: conn.assigns[:current_user] != nil

  @doc """
  Returns true if the user is an admin user

  ## Parameters

  - conn_or_user: either a `%Plug.Conn{}` struct or a `%Cforum.Accounts.User{}` struct

  ## Examples

      iex> admin?(%User{})
      false

      iex> admin?(%User{admin: true})
      true
  """
  def admin?(conn_or_user)
  def admin?(%Plug.Conn{} = conn), do: admin?(conn.assigns[:current_user])
  def admin?(%User{} = user), do: user.admin
  def admin?(_), do: false

  @doc """
  Returns true if the user may access the given forum

  ## Parameters

  - nil_conn_or_user: either a `%Plug.Conn{}` struct or a `%Cforum.Accounts.User{}` struct
  - forum: a `Cforum.Forums.Forum{}` struct; the forum to check if the user may access it
  - permission: one of `:read`, `:write` or `:moderate` (the access level). Defaults to `:read`

  ## Examples

      iex> access_forum?(%User{}, %Forum{standard_permission: "read"}, :write)
      false

      iex> access_forum?(%User{}, %Forum{standard_permission: "read})
      true
  """
  def access_forum?(nil_conn_or_user, forum, permission \\ :read)

  def access_forum?(%Plug.Conn{} = conn, forum, permission),
    do: access_forum?(conn.assigns[:current_user], forum, permission)

  def access_forum?(%User{admin: true}, _, _), do: true
  def access_forum?(user, forum, :read), do: access_forum_read?(user, forum)
  def access_forum?(user, forum, :write), do: access_forum_write?(user, forum)
  def access_forum?(user, forum, :moderate), do: access_forum_moderate?(user, forum)
  def access_forum?(_, _, _), do: false

  #
  # read access
  #

  defp access_forum_read?(_, nil), do: true

  defp access_forum_read?(nil, forum),
    do: forum.standard_permission in [ForumGroupPermission.write(), ForumGroupPermission.read()]

  defp access_forum_read?(user, forum) do
    if standard_permission_valid?(forum) do
      true
    else
      permissions = Groups.list_permissions_for_user_and_forum(user, forum)
      !blank?(permissions)
    end
  end

  #
  # write access
  #
  defp access_forum_write?(_, nil), do: true
  defp access_forum_write?(nil, forum), do: forum.standard_permission == ForumGroupPermission.write()

  defp access_forum_write?(user, forum) do
    permissions = Groups.list_permissions_for_user_and_forum(user, forum)

    cond do
      forum.standard_permission in [ForumGroupPermission.write(), ForumGroupPermission.known_write()] ->
        true

      Users.badge?(user, Badge.moderator_tools()) && generally_has_access?(permissions, forum) ->
        true

      Groups.permission?(permissions, [ForumGroupPermission.moderate(), ForumGroupPermission.write()]) ->
        true

      true ->
        false
    end
  end

  #
  # moderator access
  #
  defp access_forum_moderate?(_, nil), do: false
  defp access_forum_moderate?(nil, _), do: false

  defp access_forum_moderate?(user, forum) do
    permissions = Groups.list_permissions_for_user_and_forum(user, forum)

    if Users.badge?(user, Badge.moderator_tools()) && generally_has_access?(permissions, forum) do
      true
    else
      Groups.permission?(permissions, ForumGroupPermission.moderate())
    end
  end

  defp generally_has_access?(permissions, forum), do: !blank?(permissions) || standard_permission_valid?(forum)

  defp standard_permission_valid?(forum) do
    forum.standard_permission in [
      ForumGroupPermission.read(),
      ForumGroupPermission.write(),
      ForumGroupPermission.known_read(),
      ForumGroupPermission.known_write()
    ]
  end
end