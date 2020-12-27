defmodule CforumWeb.UsersChannel do
  use CforumWeb, :channel
  import Appsignal.Phoenix.Channel, only: [channel_action: 4]

  alias Cforum.Users.User
  alias Cforum.Forums
  alias Cforum.ConfigManager
  alias Cforum.Helpers

  alias Cforum.ReadMessages
  alias Cforum.Notifications
  alias Cforum.PrivMessages

  def join("users:lobby", _payload, socket), do: {:ok, socket}

  def join("users:" <> user_id, _payload, socket) do
    if authorized?(socket.assigns[:current_user], String.to_integer(user_id)),
      do: {:ok, socket},
      else: {:error, %{reason: "unauthorized"}}
  end

  def handle_in("current_user", _payload, socket) do
    channel_action(__MODULE__, "current_user", socket, fn ->
      {:reply, {:ok, socket.assigns[:current_user]}, socket}
    end)
  end

  def handle_in("settings", payload, socket) do
    channel_action(__MODULE__, "settings", socket, fn ->
      forum =
        if Helpers.present?(payload["current_forum"]) && payload["current_forum"] != "all",
          do: Forums.get_forum_by_slug(payload["current_forum"]),
          else: nil

      settings = Cforum.ConfigManager.settings_map(forum, socket.assigns[:current_user])

      config =
        Enum.reduce(ConfigManager.visible_config_keys(), %{}, fn key, opts ->
          Map.put(opts, key, ConfigManager.uconf(settings, key))
        end)

      {:reply, {:ok, config}, socket}
    end)
  end

  def handle_in("visible_forums", _payload, socket) do
    channel_action(__MODULE__, "visible_forums", socket, fn ->
      forums = Forums.list_visible_forums(socket.assigns[:current_user])
      {:reply, {:ok, %{forums: forums}}, socket}
    end)
  end

  def handle_in("title_infos", _payload, socket) do
    channel_action(__MODULE__, "title_infos", socket, fn ->
      forums = Forums.list_visible_forums(socket.assigns[:current_user])
      {_, num_messages} = ReadMessages.count_unread_messages(socket.assigns[:current_user], forums)

      assigns = %{
        unread_notifications: Notifications.count_notifications(socket.assigns[:current_user], true),
        unread_mails: PrivMessages.count_priv_messages(socket.assigns[:current_user], true),
        unread_messages: num_messages,
        current_user: socket.assigns[:current_user]
      }

      str = CforumWeb.LayoutView.numeric_infos(socket.assigns[:current_user], assigns)

      {:reply,
       {:ok,
        %{
          infos: str,
          unread_notifications: assigns[:unread_notifications],
          unread_mails: assigns[:unread_mails],
          unread_messages: assigns[:unread_messages]
        }}, socket}
    end)
  end

  def handle_in("mark_read", %{"message_id" => mid}, socket) do
    channel_action(__MODULE__, "mark_read", socket, fn ->
      with msg when not is_nil(msg) <- Cforum.Messages.get_message(mid),
           thread when not is_nil(thread) <- Cforum.Threads.get_thread(msg.thread_id) do
        if thread.archived == false,
          do: Cforum.ReadMessages.mark_messages_read(socket.assigns[:current_user], msg)

        {:reply, {:ok, %{"status" => "marked_read"}}, socket}
      else
        _ -> {:reply, {:error, %{"status" => "message_not_found"}}, socket}
      end
    end)
  end

  # # Channels can be used in a request/response fashion
  # # by sending replies to requests from the client
  # def handle_in("ping", payload, socket) do
  #   {:reply, {:ok, payload}, socket}
  # end

  # # It is also common to receive messages from the client and
  # # broadcast to everyone in the current topic (users:lobby).
  # def handle_in("shout", payload, socket) do
  #   broadcast(socket, "shout", payload)
  #   {:noreply, socket}
  # end

  # Add authorization logic here as required.
  defp authorized?(%User{user_id: uid}, id) when uid == id, do: true
  defp authorized?(_, _), do: false
end
