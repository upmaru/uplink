defmodule Uplink.Data.ProvisionerTest do
  use ExUnit.Case

  alias Uplink.Data.Provisioner

  import Mox

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    bypass = Bypass.open()

    Application.put_env(
      :uplink,
      Uplink.Clients.Instellar,
      endpoint: "http://localhost:#{bypass.port}/uplink"
    )

    {:ok, bypass: bypass}
  end

  test "sets up database in pro mode", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/uplink/self", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(
        200,
        Jason.encode!(%{
          "data" => %{
            "attributes" => %{
              "credential" => %{},
              "components" => [
                %{
                  "id" => 1,
                  "generator" => %{"module" => "database/postgresql"}
                }
              ]
            }
          }
        })
      )
    end)

    Bypass.expect_once(bypass, "GET", "/uplink/self/components/1", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(
        200,
        Jason.encode!(%{
          "data" => %{
            "attributes" => %{
              "generator" => %{"module" => "database/postgresql"},
              "credential" => %{
                "username" => System.get_env("POSTGRES_USERNAME"),
                "password" => System.get_env("POSTGRES_PASSWORD"),
                "host" => System.get_env("POSTGRES_HOST"),
                "port" => "5432",
                "ssl" => false
              }
            }
          }
        })
      )
    end)

    Bypass.expect_once(bypass, "POST", "/uplink/self/variables", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(
        201,
        Jason.encode!(%{
          "data" => %{
            "attributes" => %{
              "id" => 1,
              "current_state" => "inactive"
            }
          }
        })
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
          Jason.encode!(%{
            "data" => %{
              "attributes" => %{
                "id" => 1,
                "current_state" => "active",
                "credential" => %{
                  "username" => System.get_env("POSTGRES_USERNAME"),
                  "password" => System.get_env("POSTGRES_PASSWORD"),
                  "host" => System.get_env("POSTGRES_HOST"),
                  "database" => "uplink_test",
                  "port" => 5432,
                  "ssl" => false
                }
              }
            }
          })
        )
      end
    )

    Uplink.Release.TasksMock
    |> expect(:migrate, fn _options -> :ok end)

    assert {:ok, _pid} =
             start_supervised(
               {Provisioner,
                [
                  name: :provisioner_test,
                  environment: :prod,
                  parent: self()
                ]}
             )

    assert_receive :upgraded_to_pro, 1_000
  end
end
