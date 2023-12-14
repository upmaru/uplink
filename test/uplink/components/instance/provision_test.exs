defmodule Uplink.Components.Instance.ProvisionTest do
  use ExUnit.Case
  use Oban.Testing, repo: Uplink.Repo

  alias Uplink.Components.Instance

  import Mox

  setup do
    bypass = Bypass.open()

    Application.put_env(
      :uplink,
      Uplink.Clients.Instellar,
      endpoint: "http://localhost:#{bypass.port}/uplink"
    )

    {:ok, bypass: bypass}
  end

  describe "database postgresql" do
    test "provisions new postgresql database", %{bypass: bypass} do
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
                  "current_state" => "active"
                }
              }
            })
          )
        end
      )

      assert {:ok, result} =
               perform_job(Instance.Provision, %{
                 component_id: "1",
                 variable_id: "1",
                 arguments: %{"something" => "blah"}
               })

      assert %{"id" => 1} = result
    end
  end

  describe "aws s3 bucket" do
    test "provision aws s3 bucket", %{bypass: bypass} do
      Uplink.Drivers.Bucket.AwsMock
      |> expect(:provision, fn _params, options ->
        assert [acl: "private"] == options

        {:ok, %Formation.S3.Credential{}}
      end)

      Bypass.expect_once(bypass, "GET", "/uplink/self/components/1", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "data" => %{
              "attributes" => %{
                "generator" => %{"module" => "bucket/aws-s3"},
                "credential" => %{
                  "username" => "someaccesskey",
                  "password" => "somesecretkey",
                  "host" => "s3.amazonaws.com",
                  "resource" => "us-east-1"
                }
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
                  "current_state" => "active"
                }
              }
            })
          )
        end
      )

      assert {:ok, _result} =
               perform_job(Instance.Provision, %{
                 component_id: "1",
                 variable_id: "1",
                 arguments: %{"acl" => "private"}
               })
    end
  end
end
