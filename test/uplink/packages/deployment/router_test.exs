defmodule Uplink.Packages.Deployment.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Uplink.{
    Packages,
    Members
  }

  alias Packages.Deployment.Router

  @opts Router.init([])

  @valid_body Jason.encode!(%{
                "actor" => %{
                  "identifier" => "zacksiri"
                },
                "installation_id" => 1,
                "deployment" => %{
                  "hash" => "some-hash",
                  "archive_url" =>
                    "archives/7a363fba-8ca7-4ea4-8e84-f3785ac97102/packages.zip",
                  "metadata" => %{
                    "installation" => %{
                      "id" => 1,
                      "slug" => "uplink-web",
                      "service_port" => 4000,
                      "exposed_port" => 49152,
                      "instances" => [
                        %{
                          "installation_instance_id" => 1,
                          "slug" => "something-1"
                        }
                      ]
                    },
                    "cluster" => %{
                      "credential" => %{
                        "certificate" => "cert",
                        "endpoint" => "https://127.0.0.1:8443",
                        "password" => "somepassword",
                        "password_confirmation" => "somepassword",
                        "private_key" => "key"
                      },
                      "organization" => %{
                        "slug" => "upmaru"
                      }
                    },
                    "id" => 8000,
                    "package" => %{
                      "slug" => "something-1640927800",
                      "organization" => %{
                        "slug" => "upmaru"
                      }
                    }
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

    {:ok, _actor} =
      Members.create_actor(%{
        identifier: "zacksiri"
      })

    :ok
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

      assert %{"data" => %{"error" => _error}} = Jason.decode!(conn.resp_body)
    end
  end
end
