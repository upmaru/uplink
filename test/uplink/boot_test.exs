defmodule Uplink.BootTest do
  use ExUnit.Case, async: true
  use Oban.Testing, repo: Uplink.Repo

  alias Uplink.Packages
  alias Uplink.Packages.Metadata

  @deployment_params %{
    "hash" => "some-hash",
    "archive_url" => "http://localhost/archives/packages.zip",
    "channel" => "develop",
    "stack" => "alpine/3.14",
    "metadata" => %{
      "id" => 1,
      "slug" => "uplink-web",
      "main_port" => %{
        "slug" => "web",
        "source" => 49153,
        "target" => 4000
      },
      "channel" => %{
        "slug" => "develop",
        "package" => %{
          "slug" => "something-1640927800",
          "credential" => %{
            "public_key" => "public_key"
          },
          "organization" => %{
            "slug" => "upmaru"
          }
        }
      },
      "instances" => [
        %{
          "id" => 1,
          "slug" => "something-1",
          "node" => %{
            "slug" => "some-node"
          }
        }
      ]
    }
  }

  @uplink_installation_state_response %{
    "data" => %{
      "attributes" => %{
        "id" => 1,
        "slug" => "uplink-web",
        "main_port" => %{
          "slug" => "web",
          "source" => 49142,
          "target" => 4000
        },
        "variables" => [
          %{"key" => "SOMETHING", "value" => "somevalue"}
        ],
        "channel" => %{
          "slug" => "develop",
          "package" => %{
            "slug" => "something-1640927800",
            "credential" => %{
              "public_key" => "public_key"
            },
            "organization" => %{
              "slug" => "upmaru"
            }
          }
        },
        "instances" => [
          %{
            "id" => 1,
            "slug" => "something-1",
            "node" => %{
              "slug" => "some-node"
            }
          }
        ]
      }
    }
  }

  describe "boot" do
    setup do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uplink.Repo)

      metadata = Map.get(@deployment_params, "metadata")

      {:ok, metadata} = Packages.parse_metadata(metadata)

      app =
        metadata
        |> Metadata.app_slug()
        |> Packages.get_or_create_app()

      {:ok, deployment} =
        Packages.get_or_create_deployment(app, @deployment_params)

      bypass = Bypass.open()

      Uplink.Cache.put(:self, %{
        "credential" => %{
          "endpoint" => "http://localhost:#{bypass.port}"
        },
        "organization" => %{
          "slug" => "someorg",
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

      {:ok, bypass: bypass, deployment: deployment}
    end

    test "calls /uplink/self/registration when empty", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/uplink/self/registration", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: %{attributes: 1}}))
      end)

      Bypass.expect(bypass, "POST", "/uplink/self/restore", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          201,
          Jason.encode!(%{data: %{attributes: %{id: 1, installation_ids: []}}})
        )
      end)

      assert {:ok, _attributes} = Uplink.Boot.run([])
    end

    test "calls /uplink/self/registration when has install", %{
      bypass: bypass,
      deployment: deployment
    } do
      {:ok, _install} = Packages.create_install(deployment, 1)

      Bypass.expect_once(bypass, "POST", "/uplink/self/registration", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{data: %{attributes: 1}}))
      end)

      Bypass.expect_once(bypass, "GET", "/uplink/installations/1", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(@uplink_installation_state_response))
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
