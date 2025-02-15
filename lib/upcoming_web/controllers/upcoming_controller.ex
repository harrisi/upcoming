defmodule UpcomingWeb.UpcomingController do
  require Logger
  use UpcomingWeb, :controller

  def index(conn, %{"group" => group} = params) do
    get_raw = Map.get(params, "raw")

    # this is kinda messy, but, you know.
    pt =
      case :persistent_term.get(group, nil) do
        nil ->
          Logger.info("group not cached")
          nil

        cache = {_raw, event_time} ->
          if DateTime.after?(DateTime.now!("Etc/UTC"), event_time) do
            Logger.info("previously cached event passed")
            nil
          else
            Logger.info("hitting cache for group")
            cache
          end
      end

    raw =
      if pt == nil do
        {dt, raw} = do_fetch!(group)

        :persistent_term.put(group, {dt, raw})

        raw
      else
        {_dt, raw} = pt

        raw
      end

    cond do
      raw == :error -> text(conn, "unknown group: #{group}")
      get_raw != nil -> json(conn, raw)
      get_raw == nil -> redirect(conn, external: make_url(raw))
      true -> text(conn, "unknown error")
    end
  end

  def index(conn, _params) do
    json(conn, %{error: true, message: "must supply group name"})
  end

  defp make_url(raw) do
    # the link has a trailing /
    # TODO: handle errors better
    "#{Map.fetch!(raw, "link")}events/#{get_in(raw, ~W[next_event id])}"
  end

  defp do_fetch!(group) do
    case do_fetch(group) do
      {:ok, res} -> res
      {:error, res} -> res
    end
  end

  defp do_fetch(group) do
    with {:ok, res} <- HTTPoison.get("https://api.meetup.com/#{group}"),
         {:ok, body} <- Jason.decode(res.body) do
      # {:ok, next_event} <- Map.fetch(body, "next_event") do
      # %{
      #   "id" => id,
      #   "time" => time
      #   # I may want to expose this information at some point, but for now I
      #   # don't care
      #   # "utc_offset" => utc_offset
      # } = next_event

      dt =
        DateTime.from_unix!(div(get_in(body, ~W[next_event time]), 1_000))

      # for if/when I want to expose this
      # |> DateTime.shift(second: div(utc_offset, 1_000))

      Logger.info("next event at #{dt}")
      # "https://www.meetup.com/#{group}/events/#{id}", dt}}
      {:ok, {dt, body}}
    else
      err ->
        Logger.error("some error, #{inspect(err)}")

        # :persistent_term.put(group, {:error, DateTime.now!("Etc/UTC") |> DateTime.shift(year: 1)})

        {:error, {DateTime.now!("Etc/UTC") |> DateTime.shift(year: 1), :error}}
    end
  end
end
