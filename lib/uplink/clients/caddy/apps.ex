defmodule Uplink.Clients.Caddy.Apps do
	use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key false
  embedded_schema do
    embeds_one :http, Http, primary_key: false do
      field :servers, :map
    end
  end
end