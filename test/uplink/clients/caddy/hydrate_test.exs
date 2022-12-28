defmodule Uplink.Clients.Caddy.HydrateTest do
  use ExUnit.Case
  use Oban.Testing, repo: Uplink.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uplink.Repo)

    bypass = Bypass.open()

    Uplink.Cache.put(:self, %{
      "credential" => %{
        "endpoint" => "http://localhost:#{bypass.port}"
      },
      "organization" => %{
        "storage" => %{
          "type" => "s3",
          "host" => "some.host",
          "bucket" => "some-bucket",
          "region" => "sgp1",
          "credential" => %{
            "access_key_id" => "access-key",
            "secret_access_key" => "secret"
          }
        }
      }
    })

    Application.put_env(
      :uplink,
      Uplink.Clients.Caddy,
      endpoint: "http://localhost:#{bypass.port}",
      storage: %{
        prefix: "uplink"
      }
    )

    {:ok, bypass: bypass}
  end

  describe "perform hydration" do
    test "hydrates caddy", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/load", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, "")
      end)

      assert {:ok, ""} = perform_job(Uplink.Clients.Caddy.Hydrate, %{})
    end
  end
end
