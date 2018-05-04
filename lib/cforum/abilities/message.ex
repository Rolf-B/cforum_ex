defmodule Cforum.Abilities.Message do
  defmacro __using__(_opts) do
    quote do
      # TODO implement proper rights
      def may?(conn, "message", _, _), do: access_forum?(conn)

      def may?(conn, "messages/mark_read", _, _), do: signed_in?(conn)
      def may?(conn, "messages/subscription", _, _), do: signed_in?(conn)
      def may?(conn, "messages/interesting", _, _), do: signed_in?(conn)
    end
  end
end
