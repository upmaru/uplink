defmodule Uplink.Clients.Instellar.Instance do
  alias Uplink.{
    Clients
  }

  alias Clients.Instellar

  def transition(instance, install, event_name, options \\ []) do
    installation_id = install.instellar_installation_id

    [
      Instellar.endpoint(),
      "installations",
      "#{installation_id}",
      "instances",
      instance,
      "events"
    ]
    |> Path.join()
    |> Req.post!(
      {:json,
       %{
         "event" => %{
           "name" => event_name,
           "comment" => Keyword.get(options, :comment)
         }
       }},
      headers: Instellar.headers(install.deployment.hash)
    )
    |> case do
      %{status: 201, body: %{"data" => %{"attributes" => attributes}}} ->
        {:ok, attributes}

      %{status: _, body: body} ->
        {:error, body}
    end
  end
end
