defmodule Cforum.Threads.ThreadHelpers do
  import Ecto.Query, warn: false

  alias Cforum.Helpers

  alias Cforum.Repo
  alias Cforum.ConfigManager
  alias Cforum.Threads.Thread

  # "srt" as in „show read threads“
  def hide_read_threads?(conn),
    do: Cforum.ConfigManager.uconf(conn, "hide_read_threads") == "yes" && conn.params["srt"] != "yes"

  def get_ordering(conn, user) do
    cond do
      Helpers.present?(conn.params["order"]) ->
        order = conn.params["order"] |> validated_ordering(conn.assigns[:current_forum])
        {user == nil, order}

      Helpers.present?(conn.cookies["cf_order"]) && user == nil ->
        order = conn.cookies["order"] |> validated_ordering(conn.assigns[:current_forum])
        {false, order}

      true ->
        {false, ConfigManager.uconf(conn, "sort_threads")}
    end
  end

  defp validated_ordering(order, forum) do
    if Enum.member?(~w(ascending descending newest-first), order),
      do: order,
      else: Cforum.ConfigManager.conf(forum, "sort_threads")
  end

  def has_interesting?(%Thread{sorted_messages: msgs}) when not is_nil(msgs), do: has_interesting?(msgs)
  def has_interesting?(%Thread{messages: msgs}) when not is_nil(msgs), do: has_interesting?(msgs)
  def has_interesting?(messages), do: Enum.find(messages, & &1.attribs[:is_interesting]) != nil

  def valid_ordering("descending"), do: [desc: :created_at]
  def valid_ordering("ascending"), do: [asc: :created_at]
  # falling back to "newest-first" for all other cases
  def valid_ordering(_), do: [desc: :latest_message]

  def set_view_all(q, false),
    do: from(m in q, where: m.deleted == false or (m.deleted == true and not is_nil(fragment("?->>'reason'", m.flags))))

  def set_view_all(q, true), do: q

  def set_forum_id(q, visible_forums, nil) do
    visible_forums = Enum.map(visible_forums || [], & &1.forum_id)
    from(thread in q, where: thread.forum_id in ^visible_forums)
  end

  def set_forum_id(q, _, forum), do: from(thread in q, where: thread.forum_id == ^forum.forum_id)

  def slug_taken?(slug) do
    from(t in Thread, where: t.slug == ^slug)
    |> Repo.exists?()
  end

  @month_names [nil] ++ ~w[jan feb mar apr may jun jul aug sep oct nov dec]

  @doc """
  Generate a thread slug from a params map.

  ## Example

      iex> slug_from_params(%{"year" => "2017", "month" => "jan", "day" => "31", "slug" => "foo"})
      "/2017/jan/31/foo"
  """
  @spec slug_from_params(map(), boolean()) :: String.t()
  def slug_from_params(params, accept_nummeric_month \\ false)

  def slug_from_params(%{"year" => year, "month" => month, "day" => day, "slug" => slug}, false),
    do: "/#{year}/#{month}/#{day}/#{slug}"

  def slug_from_params(%{"year" => year, "month" => month, "day" => day, "slug" => slug}, _) do
    stringified_month =
      if Regex.match?(~r/^((0?[1-9])|(1[0-2]))$/, month),
        do: Enum.at(@month_names, String.to_integer(month, 10)),
        else: month

    "/#{year}/#{stringified_month}/#{day}/#{slug}"
  end
end
