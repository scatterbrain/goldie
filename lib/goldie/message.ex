defmodule Goldie.Message do
  require Logger

  @moduledoc """
  Network message manipulation.
  """

  @type t :: map 

  @doc """
  Decode a messagepack message
  """
  def decode(packet) do
    case :msgpack_nif.unpack(packet) do
      {:error, _} = err ->
        Logger.error("Message decode error #{inspect err} Packet: #{inspect packet}")
        err
      {:ok, message} ->
        {:ok, from_msgpack_format(message) |> atomify_keys}
    end
  end

  @doc """
  Encode a message to messagepack 
  """
  def encode(message) do 
    msg_pack_format = message |> Goldie.Utils.binarify_map |> to_msgpack_format
    case :msgpack_nif.pack(msg_pack_format) do
      {:error, _} = error ->
        Logger.error("Message encode error #{inspect error} Message #{inspect msg_pack_format}")
        error
      data ->
        {:ok, data}
    end
  end

  @doc """
  Make a message.
  """
  @spec new(atom, atom) :: t
  def new(command, type), do: new(command, type, %{}) 

  def new(command, type, data) do
    Map.merge(%{
      _cmd: command, 
      _type: type, 
      _id: Goldie.Utils.id()
    }, data)
  end

  @doc """
  Construct a ping.
  """
  @spec ping() :: t 
  def ping(), do: new(:ping, :cast)

  @doc """
  Construct a handshake.
  """
  @spec handshake() :: t
  def handshake() do
    msg = new(:connection, :cast) 
    ## Add 1-10 random bytes to the message to make it non uniform length
    random_bytes = :crypto.rand_bytes(:random.uniform(10)) 
    Map.put(msg, :pl, random_bytes)
  end

  @doc """
  Constructs a GameObject add message
  go_id is the GameObject id 
  """
  @spec goadd(String.t, t) :: t
  def goadd(go_id, gameobject) do
    gameobject = case Map.fetch(gameobject, :frameDelay) do
      :error ->
        Map.put(gameobject, :frameDelay, 1)
      _ ->
        gameobject
    end 
    gameobject = Map.put(gameobject, :id, go_id)
    new(:goadd, :cast, gameobject)
  end

  @doc """
  Constructs a GameObject modify message
  go_id is the GameObject id 
  """
  @spec gomodify(String.t, t) :: t
  def gomodify(go_id, changeset) do
    changeset = case Map.fetch(changeset, :frameDelay) do
      :error ->
        Map.put(changeset, :frameDelay, 1)
      _ ->
        changeset
    end 
    changeset = Map.put(changeset, :id, go_id)
    new(:gomodify, :cast, changeset)
  end

  @doc """
  Constructs a GameObject remove message
  go_id is the GameObject id 
  """
  @spec goremove(String.t, t) :: t
  def goremove(go_id, changeset) do
    changeset = Map.put(changeset, :id, go_id)
    new(:goremove, :cast, changeset)
  end

  @doc """
  Constructs a batch GameObject add/modify/remove message 
  """
  @spec gomulti(list) :: t
  def gomulti(message_list) do
    new(:gomulti, :cast, %{objects: message_list})
  end

  @doc """
  Construct a message reply.
  This copies the original message's command and id keys, and sets
  the type to result.
  """
  @spec reply(t, t) :: t
  def reply(original, data) do
    headers = Map.take(original, [:_cmd, :_id])
    new = Map.merge(headers, data)
    Map.put(new, :_type, :result)
  end

  @doc """
  Construct a message reply.
  This copies the original message's command and id keys, and sets
  the type to error.
  """
  @spec error_reply(t, t) :: t
  def error_reply(original, data) do
    headers = Map.take(original, [:_cmd, :_id])
    new = Map.merge(headers, data)
    Map.put(new, :_type, :error)
  end

  defp atomify_keys(msgpack_map) do
    Goldie.Utils.atomify_map_keys(msgpack_map)
  end

  ### Msgpack

  defp to_msgpack_format(map) when is_map(map) do
    {to_msgpack_format(Map.to_list(map))}
  end
  defp to_msgpack_format(list) when is_list(list) do
    for elem <- list, do: to_msgpack_format(elem)
  end
  defp to_msgpack_format({key, value}) do
    {key, to_msgpack_format(value)}
  end
  defp to_msgpack_format(value), do: value

  defp from_msgpack_format({[]}), do: %{}
  defp from_msgpack_format({list}) when is_list(list) do
    Enum.into(from_msgpack_format(list), %{})
  end
  defp from_msgpack_format(list) when is_list(list) do
    for elem <- list, do: from_msgpack_format(elem)
  end 
  defp from_msgpack_format({key, value}) do
    {key, from_msgpack_format(value)}
  end
  defp from_msgpack_format(value), do: value

end
