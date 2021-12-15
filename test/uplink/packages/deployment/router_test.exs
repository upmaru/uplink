defmodule Uplink.Packages.Deployment.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Uplink.{
    Packages,
    Members
  }

  alias Packages.Deployment.Router

  @opts Router.init([])

  @body Jason.encode!(%{
          "actor" => %{
            "identifier" => "zacksiri"
          },
          "installation_id" => 1,
          "deployment" => %{
            "hash" => "some-hash"
          }
        })

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uplink.Repo)

    {:ok, _actor} =
      Members.create_actor(%{
        identifier: "zacksiri"
      })

    :ok
  end

  test "returns 201 for deployment creation" do
    signature =
      :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), @body)
      |> Base.encode16()
      |> String.downcase()

    conn =
      conn(:post, "/", @body)
      |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
      |> put_req_header("content-type", "application/json")
      |> Router.call(@opts)

    assert conn.status == 201
  end
end
