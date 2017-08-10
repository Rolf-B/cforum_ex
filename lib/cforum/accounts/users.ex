defmodule Cforum.Accounts.Users do
  @moduledoc """
  The boundary for the Accounts system.
  """

  import Ecto.Query, warn: false
  alias Cforum.Repo

  alias Cforum.Accounts.User

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users(query_params \\ [order: nil, limit: nil]) do
    User
    |> Cforum.PagingApi.set_limit(query_params[:limit])
    |> Cforum.OrderApi.set_ordering(query_params[:order], [desc: :created_at])
    |> Repo.all
  end

  def count_users do
    User
    |> select(count("*"))
    |> Repo.one
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id) do
    from(u in User,
      preload: [:settings, :badges, [badges_users: :badge]],
      where: u.user_id == ^id)
    |> Repo.one!
  end

  def get_user(id) do
    from(u in User,
      preload: [:settings, :badges, [badges_users: :badge]],
      where: u.user_id == ^id)
    |> Repo.one
  end

  def get_user_by_username_or_email(login) do
    from(user in User,
      preload: [:settings, :badges, [badges_users: :badge]],
      where: user.active == true and
             (fragment("lower(?)", user.email) == fragment("lower(?)", ^login) or
              fragment("lower(?)", user.username) == fragment("lower(?)", ^login)))
    |> Repo.one
  end

  def get_user_by_reset_password_token!(reset_token) do
    Repo.get_by!(User, reset_password_token: reset_token)
  end

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def update_user_password(%User{} = user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> Ecto.Changeset.change(
      %{reset_password_token: nil,
        reset_password_sent_at: nil}
    )
    |> Repo.update()
  end

  def update_user_reset_password_token(%User{} = user, attrs) do
    user
    |> User.reset_password_token_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a User.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{source: %User{}}

  """
  def change_user(%User{} = user) do
    User.changeset(user, %{})
  end

  def change_user_password(%User{} = user) do
    User.password_changeset(user, %{})
  end

  def register_user(attrs) do
    %User{active: true}
    |> User.register_changeset(attrs)
    |> Repo.insert()
  end

  def confirm_user(token) do
    case Repo.get_by(User, confirmation_token: token) do
      nil ->
        {:error, nil}
      user ->
        update_user(user, %{confirmed_at: Timex.now})
    end
  end

  def get_reset_password_token(user) do
    token = :crypto.strong_rand_bytes(32)
    |> Base.encode64
    |> binary_part(0, 32)

    {:ok, user} = update_user_reset_password_token(user, %{reset_password_token: token,
                                                           reset_password_sent_at: Timex.now})

    user
  end

  def unique_badges(user) do
    user.badges_users
    |> Enum.reduce(%{}, fn(bu, acc) ->
      Map.update(acc, bu.badge_id,
                 %{badge: bu.badge, created_at: bu.created_at, times: 1},
                 & %{&1 | times: &1.times + 1})
    end)
    |> Map.values
    |> Enum.sort(&(&1[:times] >= &2[:times]))
  end

  def conf(nil, name), do: Cforum.ConfigManager.defaults[name]
  def conf(%User{settings: nil}, name), do: Cforum.ConfigManager.defaults[name]
  def conf(%User{settings: settings}, name) do
    settings.options[name] || Cforum.ConfigManager.defaults[name]
  end

  def authenticate_user(login, password) do
    user = get_user_by_username_or_email(login)

    cond do
      user && Comeonin.Bcrypt.checkpw(password, user.encrypted_password) ->
        {:ok, user}

      user ->
        {:error, User.login_changeset(user, %{"login" => login,
                                              "password" => password})}

      true ->
        # just waste some time for timing sidechannel attacks
        Comeonin.Bcrypt.dummy_checkpw()
        {:error, User.login_changeset(%User{}, %{"login" => login,
                                                 "password" => password})}
    end
  end

  def has_badge?(user, badge) do
    Enum.find(user.badges, &(&1.badge_type == badge)) != nil
  end

  def moderator?(%User{admin: true}), do: true
  def moderator?(user) do
    # TODO
    # user.has_badge?(Badge::MODERATOR_TOOLS) ||
    # ForumGroupPermission.exists?(['group_id IN (SELECT group_id FROM groups_users WHERE user_id = ?) ' \
    #                               'AND permission = ?', user_id, ForumGroupPermission::MODERATE])
    false
  end
end
