defmodule Uplink.BootTest do
  use ExUnit.Case
  use Oban.Testing, repo: Uplink.Repo

  describe "boot" do
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

    test "calls /uplink/self/registeration", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/uplink/self/registration", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: %{attributes: 1}}))
      end)

      assert {:ok, _attributes} = Uplink.Boot.run([])
      assert_enqueued(worker: Uplink.Clients.Caddy.Hydrate, args: %{})
    end
  end
end
