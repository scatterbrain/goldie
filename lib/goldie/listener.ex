defmodule Goldie.Listener do
  @moduledoc """
  Ranch TCP listener
  """
  def start_link(_opts) do
    ## https://github.com/ninenines/ranch/blob/master/doc/src/manual/ranch_tcp.asciidoc
    opts = [
      port: 6874,
      max_connections: :infinity
    ]
    {:ok, _} = :ranch.start_listener(
      :user,
      100,
      :ranch_tcp,
      opts,
      Goldie.Player,
      [])
  end
end
