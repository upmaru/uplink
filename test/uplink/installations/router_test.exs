defmodule Uplink.Installations.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use Oban.Testing, repo: Uplink.Repo

  import Uplink.Scenarios.Deployment

  alias Uplink.Installations.Router

  setup [:setup_endpoints, :setup_base]

  @opts Router.init([])

  @valid_delete_body Jason.encode!(%{
                       "actor" => %{
                         "provider" => "instellar",
                         "identifier" => "zacksiri",
                         "id" => "1"
                       },
                       "event" => %{
                         "name" => "delete"
                       }
                     })

  describe "delete installs" do
    setup do
      signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), @valid_delete_body)
        |> Base.encode16()
        |> String.downcase()

      {:ok, signature: signature}
    end

    test "enqueues installation delete", %{
      install: install,
      signature: signature
    } do
      conn =
        conn(
          :post,
          "/#{install.instellar_installation_id}/events",
          @valid_delete_body
        )
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert_enqueued(
        worker: Uplink.Installations.Delete,
        args: %{
          instellar_installation_id: "#{install.instellar_installation_id}"
        }
      )

      assert conn.status == 201
    end
  end
end
