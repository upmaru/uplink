defmodule Uplink.Components.Instance.ProvisionTest do
  use ExUnit.Case
  use Oban.Testing, repo: Uplink.Repo

  alias Uplink.Components.Instance

  @get_component_response %{
    "data" => %{
      "attributes" => %{
        "generator" => %{"module" => "database/postgresql"},
        "credential" => %{
          "username" => System.get_env("POSTGRES_USERNAME"),
          "password" => System.get_env("POSTGRES_PASSWORD"),
          "host" => System.get_env("POSTGRES_HOST"),
          "port" => "5432"
        }
      }
    }
  }

  @create_component_instance_response %{
    "data" => %{
      "attributes" => %{
        "id" => 1,
        "current_state" => "active"
      }
    }
  }

  setup do
    bypass = Bypass.open()

    Application.put_env(
      :uplink,
      Uplink.Clients.Instellar,
      endpoint: "http://localhost:#{bypass.port}/uplink"
    )

    {:ok, bypass: bypass}
  end

  describe "perform" do
    test "provisions new postgresql database", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/uplink/self/components/1", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(@get_component_response)
        )
      end)

      Bypass.expect_once(
        bypass,
        "POST",
        "/uplink/self/components/1/instances",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(
            201,
            Jason.encode!(@create_component_instance_response)
          )
        end
      )

      assert {:ok, result} =
               perform_job(Instance.Provision, %{
                 component_id: "1",
                 variable_id: "1"
               })

      assert %{"id" => 1} = result
    end
  end
end
