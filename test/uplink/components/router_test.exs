defmodule Uplink.Components.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use Oban.Testing, repo: Uplink.Repo

  alias Uplink.Components.Instance
  alias Uplink.Components.Router

  @opts Router.init([])

  @valid_modify_body Jason.encode!(%{
                       "actor" => %{
                         "provider" => "instellar",
                         "identifier" => "zacksiri",
                         "id" => "1"
                       },
                       "component_instance_id" => "1",
                       "variable_id" => "1",
                       "arguments" => %{}
                     })

  @incomplete_body Jason.encode!(%{
                     "actor" => %{
                       "provider" => "instellar",
                       "identifier" => "zacksiri",
                       "id" => "1"
                     },
                     "arguments" => %{}
                   })

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uplink.Repo)
  end

  describe "provision" do
    test "successfully enqueue provision job" do
      tasks =
        1..2
        |> Enum.to_list()
        |> Enum.map(fn n ->
          Task.async(fn ->
            provision_body =
              Jason.encode!(%{
                "actor" => %{
                  "provider" => "instellar",
                  "identifier" => "zacksiri",
                  "id" => "1"
                },
                "variable_id" => "#{n}",
                "arguments" => %{}
              })

            signature =
              :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), provision_body)
              |> Base.encode16()
              |> String.downcase()

            conn =
              conn(:post, "/#{n}/instances", provision_body)
              |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
              |> put_req_header("content-type", "application/json")
              |> Router.call(@opts)

            %{conn: conn, index: n}
          end)
        end)

      tasks_with_results = Task.yield_many(tasks)

      Enum.each(tasks_with_results, fn {_task, result} ->
        {:ok, %{conn: conn, index: index}} = result

        assert conn.status == 201

        assert %{"data" => %{"id" => _job_id}} = Jason.decode!(conn.resp_body)

        assert_enqueued(
          worker: Instance.Provision,
          args: %{
            "variable_id" => "#{index}",
            "component_id" => "#{index}",
            "arguments" => %{}
          }
        )
      end)
    end
  end

  describe "modify" do
    setup do
      signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), @valid_modify_body)
        |> Base.encode16()
        |> String.downcase()

      {:ok, signature: signature}
    end

    test "successfully enqueue modify job", %{signature: signature} do
      conn =
        conn(:post, "/1/instances", @valid_modify_body)
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 201

      assert %{"data" => %{"id" => _job_id}} = Jason.decode!(conn.resp_body)

      assert_enqueued(
        worker: Instance.Modify,
        args: %{
          "component_instance_id" => "1",
          "variable_id" => "1",
          "component_id" => "1",
          "arguments" => %{}
        }
      )
    end
  end

  describe "error" do
    setup do
      signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), @incomplete_body)
        |> Base.encode16()
        |> String.downcase()

      {:ok, signature: signature}
    end

    test "error message", %{signature: signature} do
      conn =
        conn(:post, "/1/instances", @incomplete_body)
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 422
    end
  end
end
