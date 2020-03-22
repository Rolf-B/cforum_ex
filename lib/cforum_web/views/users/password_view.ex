defmodule CforumWeb.Users.PasswordView do
  use CforumWeb, :view

  alias CforumWeb.Views.ViewHelpers
  alias CforumWeb.Views.ViewHelpers.Path
  alias CforumWeb.ErrorHelpers

  def page_title(action, _) when action in [:new, :create], do: gettext("Send password reset instructions")
  def page_title(action, _) when action in [:edit_reset, :update_reset], do: gettext("Reset my password")

  def page_title(action, assigns) when action in [:edit, :update],
    do: gettext("change password: %{username}", username: assigns[:user].username)

  def page_heading(action, assigns), do: page_title(action, assigns)

  def body_id(action, _), do: "users-password-#{action}"

  def body_classes(action, _), do: "users password #{action}"
end
