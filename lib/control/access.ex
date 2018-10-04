defmodule Control.Access do
  import Kernel, except: [get_in: 2, update_in: 3, get_and_update_in: 3]
  defdelegate all, to: Access
  defdelegate at(idx), to: Access
  defdelegate elem(idx), to: Access
  defdelegate key(k, default \\ nil), to: Access
  defdelegate key!(k), to: Access

  defdelegate fetch(t, k), to: Access
  defdelegate get(t, k, default \\ nil), to: Access
  defdelegate get_and_update(t, k, f), to: Access
  defdelegate pop(t, k), to: Access

  def fetch!(x, k) do
    case fetch(x, k) do
      {:ok, y} -> y
      :error -> raise(KeyError, key: k, term: x)
    end
  end

  def each do &each/3 end
  def each(op, data, next) do all().(op, Enum.to_list(data), next) end

  def each(t) do
    now = all()
    fn
      :get_and_update = op, data, next ->
        {get, update} = now.(op, Enum.to_list(data), next)
        {Enum.into(get, t), Enum.into(update, t)}

      :get = op, data, next ->
        now.(op, Enum.to_list(data), next)
        |> Enum.into(t)
    end
  end

  def values do &values/3 end
  def values(op, data, next) do all().(op, Enum.to_list(data), fn x -> elem(1).(op, x, next) end) end

  def values(t) do
    now = all()
    fn
      :get_and_update = op, data, next ->
        {get, update} = now.(op, Enum.to_list(data), fn x -> elem(1).(op |> IO.inspect(), x, next) |> IO.inspect() end)
        {Enum.into(get, t), Enum.into(update, t)}

      :get = op, data, next ->
        now.(op, Enum.to_list(data), fn x -> elem(1).(op, x, next) end)
        |> Enum.into(t)
    end
  end
  def map_as_list do &go_map_as_list/3 end

  def go_map_as_list(:get, data, next) do next.(Enum.to_list(data)) end
  def go_map_as_list(:get_and_update, data, next) do Kernel.update_in(next.(Enum.to_list(data)), [Access.elem(1)], &Map.new/1) end

  def map_values(:get, data, next) do Enum.map(data, next) end

  def get_in(t, [x]) when is_function(x, 3) do x.(:get, t, fn x -> x end) end
  def get_in(t, [x | xs]) when is_function(x, 3) do x.(:get, t, &get_in(&1, xs)) end
  def get_in(nil, [_]) do nil end
  def get_in(nil, [_ | xs]) do get_in(nil, xs) end
  def get_in(t, [x]) do Access.get(t, x) end
  def get_in(t, [x | xs]) do get_in(Access.get(t, x), xs) end

  def get_and_update_in(t, [x], f) when is_function(x, 3) do x.(:get_and_update, t, f) end
  def get_and_update_in(t, [x | xs], f) when is_function(x, 3) do x.(:get_and_update, t, &__MODULE__.get_and_update_in(&1, xs, f)) end
  def get_and_update_in(t, [x], f) do Access.get_and_update(t, x, f) end
  def get_and_update_in(t, [x | xs], f) do Access.get_and_update(t, x, fn t -> __MODULE__.get_and_update_in(t, xs, f) end) end

  def update_in(t, [x], f) when is_function(x, 3) do x.(:update, t, f) end
  def update_in(t, [x | xs], f) when is_function(x, 3) do x.(:update, t, &__MODULE__.update_in(&1, xs, f)) end
  def update_in(t, [x], f) do Access.get_and_update(t, x, fn x -> {nil, f.(x)} end) |> elem(1) end
  def update_in(t, [x | xs], f) do Access.get_and_update(t, x, fn t -> {nil, __MODULE__.update_in(t, xs, f)} end) |> elem(1) end

  # Accessors

  #def all() do
  #  &all/3
  #end

  #def all(:get, data, next) when is_list(data) do
  #  Enum.map(data, next)
  #end

  #def all(:get_and_update, data, next) when is_list(data) do
  #  all(data, next, [], [])
  #end

  #def all(:update, data, next) when is_list(data) do
  #  all(data, next, [], [])
  #end

  #def all(:pop, data, next) when is_list(data) do
  #  all(data, next, [], [])
  #end

  #def all(_op, data, _next) do
  #  raise "Access.all/0 expected a list, got: #{inspect data}"
  #end

  #def all([head | rest], next, gets, updates) do
  #  case next.(head) do
  #    {get, update} -> all(rest, next, [get | gets], [update | updates])
  #    :pop -> all(rest, next, [head | gets], updates)
  #  end
  #end

  #def all([], _next, gets, updates) do
  #  {:lists.reverse(gets), :lists.reverse(updates)}
  #end
end
