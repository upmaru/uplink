defmodule Uplink.Packages.Deployment.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Uplink.{
    Packages,
    Members
  }

  alias Packages.Deployment.Router

  @opts Router.init([])

  @app_slug "upmaru/something-1640927800"

  @valid_body Jason.encode!(%{
                "actor" => %{
                  "identifier" => "zacksiri"
                },
                "installation_id" => 1,
                "deployment" => %{
                  "hash" => "some-hash",
                  "stack" => "alpine/3.14",
                  "channel" => "develop",
                  "archive_url" =>
                    "archives/7a363fba-8ca7-4ea4-8e84-f3785ac97102/packages.zip",
                  "metadata" => %{
                    "id" => 1,
                    "slug" => "uplink-web",
                    "service_port" => 4000,
                    "exposed_port" => 49152,
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
              })

  @invalid_body Jason.encode!(%{
                  "actor" => %{
                    "identifier" => "zacksiri"
                  },
                  "installation_id" => 1,
                  "deployment" => %{
                    "hash" => "some-hash",
                    "archive_path" =>
                      "archives/7a363fba-8ca7-4ea4-8e84-f3785ac97102/packages.zip",
                    "metadata" => %{}
                  }
                })

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uplink.Repo)

    {:ok, actor} =
      Members.create_actor(%{
        identifier: "zacksiri"
      })

    {:ok, actor: actor}
  end

  describe "valid body" do
    test "returns 201 for deployment creation" do
      signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), @valid_body)
        |> Base.encode16()
        |> String.downcase()

      conn =
        conn(:post, "/", @valid_body)
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 201

      assert %{"data" => %{"id" => _deployment_id}} =
               Jason.decode!(conn.resp_body)
    end
  end

  describe "invalid body" do
    test "returns 422 for deployment creation" do
      signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), @invalid_body)
        |> Base.encode16()
        |> String.downcase()

      conn =
        conn(:post, "/", @invalid_body)
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 422

      assert %{"data" => %{"errors" => _errors}} = Jason.decode!(conn.resp_body)
    end
  end

  describe "create install event" do
    setup %{actor: actor} do
      deployment = Map.get(Jason.decode!(@valid_body), "deployment")

      {:ok, metadata} = Packages.parse_metadata(deployment["metadata"])

      app = Packages.get_or_create_app(@app_slug)

      {:ok, deployment} = Packages.get_or_create_deployment(app, deployment)

      {:ok, install} = Packages.create_install(deployment, metadata.id)

      {:ok, %{resource: validating_install}} =
        Packages.transition_install_with(install, actor, "validate")

      {:ok, %{resource: _executing_install}} =
        Packages.transition_install_with(validating_install, actor, "execute")

      body =
        Jason.encode!(%{
          "actor" => %{
            "identifier" => "zacksiri"
          },
          "event" => %{
            "name" => "complete",
            "comment" => "installation synced successful"
          }
        })

      signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), body)
        |> Base.encode16()
        |> String.downcase()

      {:ok,
       body: body,
       install: validating_install,
       signature: signature,
       deployment: deployment,
       metadata: metadata}
    end

    test "can mark install complete", %{
      body: body,
      deployment: deployment,
      install: install,
      signature: signature,
      metadata: metadata
    } do
      {:ok, %{resource: _executing_install}} =
        Packages.transition_install_with(validating_install, actor, "execute")

      conn =
        conn(:post, "/#{deployment.hash}/installs/#{metadata.id}/events", body)
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 201
      assert %{"data" => data} = Jason.decode!(conn.resp_body)
      assert %{"id" => _id, "name" => "complete"} = data
    end
  end
end
