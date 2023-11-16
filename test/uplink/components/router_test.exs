defmodule Uplink.Components.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use Oban.Testing, repo: Uplink.Repo

  alias Uplink.Components.Instance
  alias Uplink.Components.Router

  @opts Router.init([])

  @valid_body Jason.encode!(%{
                "actor" => %{
                  "provider" => "instellar",
                  "identifier" => "zacksiri",
                  "id" => "1"
                },
                "variable_id" => "1",
                "arguments" => %{}
              })

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uplink.Repo)

    signature =
      :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), @valid_body)
      |> Base.encode16()
      |> String.downcase()

    {:ok, signature: signature}
  end

  describe "create component instance provisioning job" do
    test "successfully", %{signature: signature} do
      conn =
        conn(:post, "/1/instances", @valid_body)
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 201

      assert %{"data" => %{"id" => _job_id}} = Jason.decode!(conn.resp_body)

      assert_enqueued(
        worker: Instance.Provision,
        args: %{"variable_id" => "1", "component_id" => "1", "arguments" => %{}}
      )
    end
  end
end
