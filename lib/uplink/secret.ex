defmodule Uplink.Secret do
  def get do
    Application.get_env(:uplink, __MODULE__)
  end

  defmodule Signature do
    def compute_signature(content) do
      secret = Uplink.Secret.get()

      :crypto.mac(:hmac, :sha256, secret, content)
      |> Base.encode16()
      |> String.downcase()
    end
  end
end
