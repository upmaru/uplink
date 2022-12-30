defmodule Uplink.BootTest do
  use ExUnit.Case
  use Oban.Testing, repo: Uplink.Repo

  describe "boot" do
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
        Uplink.Clients.Instellar,
        endpoint: "http://localhost:#{bypass.port}/uplink"
      )

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

    test "calls /uplink/self/registeration", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/uplink/self/registration", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: %{attributes: 1}}))
      end)

      Bypass.expect(bypass, "POST", "/load", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, "")
      end)

      assert {:ok, _attributes} = Uplink.Boot.run([])

      assert_enqueued(
        worker: Uplink.Packages.Archive.Hydrate.Schedule,
        args: %{}
      )
    end
  end
end
