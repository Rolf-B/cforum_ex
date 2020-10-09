defmodule Cforum.Application do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    :telemetry.attach("appsignal-ecto", [:cforum, :repo, :query], &Appsignal.Ecto.handle_event/4, nil)
    :telemetry.attach("oban-failure", [:oban, :job, :exception], &Cforum.Jobs.Appsignal.handle_event/4, nil)
    :telemetry.attach("oban-success", [:oban, :job, :stop], &Cforum.Jobs.Appsignal.handle_event/4, nil)

    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      Cforum.Repo,
      # Start the Telemetry supervisor
      CforumWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Cforum.PubSub},
      # Start the endpoint when the application starts
      CforumWeb.Endpoint,
      {Oban, Application.get_env(:cforum, Oban)},
      # Start your own worker by calling: Cforum.Worker.start_link(arg1, arg2, arg3)
      # worker(Cforum.Worker, [arg1, arg2, arg3]),
      {Cachex, name: :cforum},
      :poolboy.child_spec(Cforum.MarkdownRenderer.pool_name(), poolboy_config(:markdown), [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Cforum.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    CforumWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp poolboy_config(:markdown) do
    conf = Application.get_env(:cforum, :cfmarkdown)

    [
      {:name, {:local, Cforum.MarkdownRenderer.pool_name()}},
      {:worker_module, Cforum.MarkdownRenderer},
      {:size, Keyword.get(conf, :pool_size, 5)},
      {:max_overflow, Keyword.get(conf, :max_overflow, 2)}
    ]
  end
end
