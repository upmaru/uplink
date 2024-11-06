defmodule Uplink.Instances do
  alias Uplink.Cache

  def exists?(state, install_id, instance_name) do
    Cache.get({:install, install_id, state})
    |> case do
      nil -> false
      member_instances -> Enum.member?(member_instances, instance_name)
    end
  end

  def mark(state, install_id, instance_name) do
    Cache.transaction(
      [keys: [{:install, install_id, state}]],
      fn ->
        Cache.get_and_update(
          {:install, install_id, state},
          fn current_value ->
            executing_instances =
              if current_value,
                do: current_value ++ [instance_name],
                else: [instance_name]

            {current_value, Enum.uniq(executing_instances)}
          end
        )
      end
    )
  end
end
