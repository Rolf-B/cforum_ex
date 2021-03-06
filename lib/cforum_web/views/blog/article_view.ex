defmodule CforumWeb.Blog.ArticleView do
  use CforumWeb, :view

  alias Cforum.Helpers
  alias Cforum.ConfigManager
  alias Cforum.Abilities

  alias CforumWeb.Views.ViewHelpers.Path
  alias CforumWeb.Views.ViewHelpers
  alias CforumWeb.ErrorHelpers

  def page_title(:show, %{article: thread, conn: conn}) do
    msg = thread.message

    msg.subject <>
      " " <>
      gettext("by") <>
      " " <> msg.author <> ", " <> ViewHelpers.format_date(conn, msg.created_at, "date_format_post")
  end

  def page_title(action, _assigns) when action in [:new, :create], do: gettext("new thread")

  def page_title(action, %{article: thread}) when action in [:edit, :update] do
    gettext("edit message “%{subject}” by %{author}", subject: thread.message.subject, author: thread.message.author)
  end

  def body_id(action, _assigns), do: "weblog-#{action}"
  def body_classes(action, assigns), do: "weblog forum-#{Path.forum_slug(assigns[:current_forum])} #{action}"

  def excerpt(conn, message) do
    if Helpers.present?(message.excerpt),
      do: Cforum.MarkdownRenderer.to_html(message, conn, :excerpt),
      else: excerpt_from_content(conn, message)
  end

  defp excerpt_from_content(conn, message) do
    {:safe, content} = Cforum.MarkdownRenderer.to_html(message, conn)

    new_content =
      content
      |> String.replace(~r/<p>\s*<\/p>/s, "")
      |> String.replace(~r/(<\/p>|<!--more-->).*/s, "\\1")

    {:safe, new_content}
  end
end
