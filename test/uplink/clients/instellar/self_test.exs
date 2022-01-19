defmodule Uplink.Clients.Instellar.SelfTest do
  use ExUnit.Case

  alias Uplink.Cache

  @response %{
    "data" => %{
      "attributes" => %{
        "id" => 1,
        "credential" => %{
          "endpoint" => "http://127.0.0.1:8443",
          "certificate" => "somecert",
          "private_key" => "someprivatekey"
        }
      }
    }
  }

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uplink.Repo)

    bypass = Bypass.open()

    Application.put_env(
      :uplink,
      Uplink.Clients.Instellar,
      endpoint: "http://localhost:#{bypass.port}/uplink"
    )

    {:ok, bypass: bypass}
  end

  describe "when not cached" do
    alias Uplink.Clients.Instellar.Self

    setup do
      Cache.delete(:self)

      :ok
    end

    test "fetch and store cluster credential", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/uplink/self", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(@response))
      end)

      assert %{"credential" => _credential} = Self.show()
    end
  end

  describe "when cached" do
    alias Uplink.Clients.Instellar.Self

    setup do
      Cache.put(:self, @response["data"]["attributes"])

      :ok
    end

    test "return credential without network call" do
      assert %{"credential" => _credential} = Self.show()
    end
  end
end
