defmodule Uplink.Components.Instance.Enqueue do
  alias Uplink.Components.Instance.Modify
  alias Uplink.Components.Instance.Provision

  def job(
        component_id,
        %{
          "arguments" => argument_params,
          "component_instance_id" => component_instance_id,
          "variable_id" => variable_id
        }
      ) do
    %{
      component_id: component_id,
      variable_id: variable_id,
      component_instance_id: component_instance_id,
      arguments: argument_params
    }
    |> Modify.new()
    |> Oban.insert()
  end

  def job(
        component_id,
        %{
          "arguments" => argument_params,
          "variable_id" => variable_id
        }
      ) do
    %{
      component_id: component_id,
      variable_id: variable_id,
      arguments: argument_params
    }
    |> Provision.new()
    |> Oban.insert()
  end

  def job(_, _), do: {:error, :unprocessable_entity}
end
