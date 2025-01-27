defmodule UpcomingWeb.UpcomingController do
  require Logger
  use UpcomingWeb, :controller

  def index(conn, %{"group" => group} = params) do
    only_url = Map.get(params, "url")

    with {:ok, res} <- HTTPoison.get("https://api.meetup.com/#{group}"),
         {:ok, body} <- JSON.decode(res.body),
         {:ok, next_event} <- Map.fetch(body, "next_event") do
      # these should all be here, I think.
      %{
        "id" => id,
        "time" => time,
        "utc_offset" => utc_offset
      } = next_event

      dt =
        DateTime.from_unix!(div(time, 1_000))
        |> DateTime.shift(second: div(utc_offset, 1_000))

      Logger.info("next event at #{dt}")
      url = "https://www.meetup.com/#{group}/events/#{id}"

      if only_url do
        json(conn, %{url: url})
      else
        redirect(conn, external: url)
      end
    else
      _ ->
        Logger.error("some error")
        url = "https://www.meetup.com/#{group}/events"

        if only_url do
          json(conn, %{error: true, url: url})
        else
          redirect(conn, external: url)
        end
    end
  end

  def index(conn, _params) do
    json(conn, %{error: true, message: "must supply group name"})
  end
end
