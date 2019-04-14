defmodule CforumWeb.Messages.SubscriptionController do
  use CforumWeb, :controller

  alias Cforum.Forums.{Threads, Messages, Thread}
  alias CforumWeb.Views.Helpers.ReturnUrl
  alias Cforum.Search
  alias Cforum.Search.Finder

  def index(conn, %{"search" => %{"term" => term} = search_params} = params) when not is_nil(term) and term != "" do
    visible_sections = Search.list_visible_search_sections(conn.assigns.visible_forums)

    changeset =
      Search.search_changeset(
        visible_sections,
        Map.put(search_params, "sections", Enum.map(visible_sections, & &1.search_section_id))
      )

    count = Finder.count_subscribed_messages_results(conn.assigns[:current_user], changeset)
    paging = paginate(count, page: params["p"])

    threads =
      Finder.search_subscribed_messages(conn.assigns.current_user, changeset, paging.params)
      |> Enum.map(fn msg -> %Thread{msg.thread | messages: [msg]} end)
      |> Threads.apply_user_infos(conn.assigns[:current_user])
      |> Threads.apply_highlights(conn)
      |> Enum.map(fn thread -> %Thread{thread | message: List.first(thread.messages)} end)

    render(conn, "index.html", threads: threads, paging: paging, changeset: changeset)
  end

  def index(conn, params) do
    visible_sections = Search.list_visible_search_sections(conn.assigns.visible_forums)
    changeset = Search.search_changeset(visible_sections)
    count = Messages.count_subscriptions(conn.assigns[:current_user])
    paging = paginate(count, page: params["p"])

    entries = Messages.list_subscriptions(conn.assigns[:current_user], limit: paging.params)

    threads =
      entries
      |> Enum.map(fn msg -> %Thread{msg.thread | messages: [msg]} end)
      |> Threads.apply_user_infos(conn.assigns[:current_user])
      |> Threads.apply_highlights(conn)
      |> Enum.map(fn thread -> %Thread{thread | message: List.first(thread.messages)} end)

    render(conn, "index.html", threads: threads, paging: paging, changeset: changeset)
  end

  def subscribe(conn, params) do
    Messages.subscribe_message(conn.assigns[:current_user], conn.assigns.message)

    conn
    |> put_flash(:info, gettext("Message was successfully subscribed."))
    |> redirect(to: ReturnUrl.return_path(conn, params, conn.assigns.thread))
  end

  def unsubscribe(conn, params) do
    Messages.unsubscribe_message(conn.assigns[:current_user], conn.assigns.message)

    conn
    |> put_flash(:info, gettext("Message was successfully unsubscribed."))
    |> redirect(to: ReturnUrl.return_path(conn, params, conn.assigns.thread))
  end

  def load_resource(conn) do
    if Phoenix.Controller.action_name(conn) == :index do
      conn
    else
      thread =
        Threads.get_thread_by_slug!(conn.assigns[:current_forum], nil, Threads.slug_from_params(conn.params))
        |> Threads.reject_deleted_threads(conn.assigns[:view_all])
        |> Threads.apply_user_infos(conn.assigns[:current_user], omit: [:read, :interesting, :open_close])
        |> Threads.apply_highlights(conn)
        |> Threads.build_message_tree(uconf(conn, "sort_messages"))

      message = Messages.get_message_from_mid!(thread, conn.params["mid"])

      conn
      |> Plug.Conn.assign(:thread, thread)
      |> Plug.Conn.assign(:message, message)
    end
  end

  def allowed?(conn, :subscribe, message) do
    message = message || conn.assigns.message
    Abilities.signed_in?(conn) && message.attribs[:is_subscribed] != true
  end

  def allowed?(conn, :unsubscribe, message) do
    message = message || conn.assigns.message
    Abilities.signed_in?(conn) && message.attribs[:is_subscribed] == true
  end

  def allowed?(conn, _, _), do: Abilities.signed_in?(conn)
end
