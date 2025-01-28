defmodule UpcomingWeb.UpcomingController do
  require Logger
  use UpcomingWeb, :controller

  def index(conn, %{"group" => group} = params) do
    only_url = Map.get(params, "url")

    # this is kinda messy, but, you know.
    pt =
      case :persistent_term.get(group, nil) do
        nil ->
          Logger.info("group not cached")
          nil

        cache = {_url, event_time} ->
          if DateTime.after?(DateTime.now!("Etc/UTC"), event_time) do
            Logger.info("previously cached event passed")
            nil
          else
            Logger.info("hitting cache for group")
            cache
          end
      end

    url =
      if pt == nil do
        {url, dt} = do_fetch!(group)

        :persistent_term.put(group, {url, dt})

        url
      else
        {url, _dt} = pt

        url
      end

    if only_url do
      text(conn, url)
    else
      redirect(conn, external: url)
    end
  end

  def index(conn, _params) do
    json(conn, %{error: true, message: "must supply group name"})
  end

  defp do_fetch!(group) do
    case do_fetch(group) do
      {:ok, res} -> res
      {:error, err} -> raise err
    end
  end

  defp do_fetch(group) do
    with {:ok, res} <- HTTPoison.get("https://api.meetup.com/#{group}"),
         {:ok, body} <- Jason.decode(res.body),
         {:ok, next_event} <- Map.fetch(body, "next_event") do
      %{
        "id" => id,
        "time" => time
        # I may want to expose this information at some point, but for now I
        # don't care
        # "utc_offset" => utc_offset
      } = next_event

      dt =
        DateTime.from_unix!(div(time, 1_000))

      # for if/when I want to expose this
      # |> DateTime.shift(second: div(utc_offset, 1_000))

      Logger.info("next event at #{dt}")
      {:ok, {"https://www.meetup.com/#{group}/events/#{id}", dt}}
    else
      _ ->
        Logger.error("some error")
        {:error, "https://www.meetup.com/#{group}/events"}
    end
  end
end
