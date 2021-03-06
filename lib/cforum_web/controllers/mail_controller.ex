defmodule CforumWeb.MailController do
  use CforumWeb, :controller

  alias Cforum.PrivMessages.PrivMessage
  alias Cforum.PrivMessages
  alias Cforum.Messages

  alias Cforum.Abilities
  alias Cforum.ConfigManager
  alias Cforum.Helpers

  alias CforumWeb.Views.ViewHelpers
  alias CforumWeb.Sortable
  alias CforumWeb.Paginator

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    sort_dir = ConfigManager.uconf(conn, "mail_thread_sort")

    {sort_params, conn} =
      Sortable.sort_collection(conn, [:created_at, :subject, :is_read, :partner], dir: ordering(sort_dir))

    count = PrivMessages.count_newest_priv_messages_of_each_thread(conn.assigns[:current_user])
    paging = Paginator.paginate(count, page: params["p"])

    mails =
      PrivMessages.list_newest_priv_messages_of_each_thread(
        conn.assigns[:current_user],
        limit: paging.params,
        order: sort_params,
        messages_order: ordering(sort_dir),
        author: params["author"]
      )

    render(conn, "index.html", mails: mails, paging: paging)
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => _id}) do
    Cforum.Helpers.AsyncHelper.run_async(fn ->
      Enum.each(conn.assigns.pm_thread, &PrivMessages.mark_priv_message(&1, :read))
    end)

    render(conn, "show.html")
  end

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(conn, %{"parent_id" => id} = params) do
    parent = PrivMessages.get_priv_message!(conn.assigns[:current_user], id)

    changeset =
      PrivMessages.answer_changeset(
        %PrivMessage{},
        parent,
        strip_signature: ConfigManager.uconf(conn, "quote_signature") != "yes",
        greeting: ConfigManager.uconf(conn, "greeting"),
        farewell: ConfigManager.uconf(conn, "farewell"),
        signature: ConfigManager.uconf(conn, "signature"),
        quote: quote?(params),
        std_replacement: gettext("you")
      )

    render(conn, "new.html", changeset: changeset, parent: parent)
  end

  def new(conn, %{"message_id" => id}) do
    message = Messages.get_message!(id)

    changeset =
      PrivMessages.new_changeset(
        %PrivMessage{},
        %{
          subject:
            gettext("regarding your message %{subject} from %{time}",
              subject: message.subject,
              time: ViewHelpers.format_date(conn, message.created_at, "date_format_post")
            ),
          recipient_id: message.user_id
        },
        greeting: ConfigManager.uconf(conn, "greeting"),
        farewell: ConfigManager.uconf(conn, "farewell"),
        signature: ConfigManager.uconf(conn, "signature"),
        std_replacement: gettext("you"),
        author: message.author
      )

    render(conn, "new.html", changeset: changeset)
  end

  def new(conn, params) do
    changeset =
      PrivMessages.new_changeset(
        %PrivMessage{},
        params["priv_message"] || %{},
        greeting: ConfigManager.uconf(conn, "greeting"),
        farewell: ConfigManager.uconf(conn, "farewell"),
        signature: ConfigManager.uconf(conn, "signature"),
        std_replacement: gettext("you")
      )

    render(conn, "new.html", changeset: changeset)
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"priv_message" => priv_message_params} = params) do
    if Map.has_key?(params, "preview"),
      do: show_preview(conn, priv_message_params),
      else: create_message(conn, priv_message_params)
  end

  defp show_preview(conn, params) do
    {priv_message, changeset} = PrivMessages.preview_priv_message(params)
    render(conn, "new.html", changeset: changeset, priv_message: priv_message, preview: true)
  end

  defp create_message(conn, priv_message_params) do
    case PrivMessages.create_priv_message(conn.assigns[:current_user], priv_message_params) do
      {:ok, priv_message} ->
        conn
        |> put_flash(:info, gettext("Mail created successfully."))
        |> redirect(to: Path.mail_thread_path(conn, :show, priv_message))

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  @spec update_unread(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_unread(conn, %{"id" => _id}) do
    PrivMessages.mark_priv_message(conn.assigns.priv_message, :unread)

    conn
    |> put_flash(:info, gettext("Mail successfully marked as unread."))
    |> redirect(to: Path.mail_path(conn, :index))
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => _id} = params) do
    msg =
      if params["thread"] == "yes" do
        PrivMessages.delete_thread(conn.assigns.priv_message)
        gettext("Thread deleted successfully.")
      else
        PrivMessages.delete_priv_message(conn.assigns.priv_message)
        gettext("Mail deleted successfully.")
      end

    conn
    |> put_flash(:info, msg)
    |> redirect(to: Path.mail_path(conn, :index))
  end

  defp ordering("ascending"), do: :asc
  defp ordering(_), do: :desc

  defp quote?(params) do
    if Helpers.blank?(params["quote"]),
      do: true,
      else: params["quote"] == "yes"
  end

  @spec load_resource(Plug.Conn.t()) :: Plug.Conn.t()
  def load_resource(%{assigns: %{current_user: nil}} = conn), do: conn

  def load_resource(conn) do
    cond do
      action_name(conn) in [:delete, :update_unread] ->
        pm = PrivMessages.get_priv_message!(conn.assigns[:current_user], conn.params["id"])
        Plug.Conn.assign(conn, :priv_message, pm)

      action_name(conn) == :show ->
        sort_dir = ConfigManager.uconf(conn, "mail_thread_sort")

        thread =
          PrivMessages.get_priv_message_thread!(conn.assigns[:current_user], conn.params["id"],
            messages_order: ordering(sort_dir)
          )

        id = String.to_integer(conn.params["id"])
        priv_message = Enum.find(thread, &(&1.priv_message_id == id))

        conn
        |> Plug.Conn.assign(:pm_thread, thread)
        |> Plug.Conn.assign(:priv_message, priv_message)

      action_name(conn) in [:new, :create] && Helpers.present?(conn.params["parent_id"]) ->
        pm = PrivMessages.get_priv_message!(conn.assigns[:current_user], conn.params["parent_id"])
        Plug.Conn.assign(conn, :priv_message, pm)

      true ->
        conn
    end
  end

  @spec allowed?(Plug.Conn.t(), atom(), any()) :: boolean()
  def allowed?(conn, :index, _), do: Abilities.signed_in?(conn)

  def allowed?(conn, :show, resource) do
    resource = resource || conn.assigns[:pm_thread]
    Abilities.signed_in?(conn) && conn.assigns[:current_user].user_id == List.first(resource).owner_id
  end

  def allowed?(conn, action, resource) when action in [:new, :create] do
    if conn.params["parent_id"] || resource do
      resource = resource || conn.assigns[:priv_message]
      Abilities.signed_in?(conn) && conn.assigns[:current_user].user_id == resource.owner_id
    else
      Abilities.signed_in?(conn)
    end
  end

  def allowed?(conn, _, resource) do
    resource = resource || conn.assigns[:priv_message]
    Abilities.signed_in?(conn) && conn.assigns[:current_user].user_id == resource.owner_id
  end
end
