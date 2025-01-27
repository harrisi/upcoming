defmodule UpcomingWeb.Router do
  use UpcomingWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", UpcomingWeb do
    pipe_through :api

    get "/", UpcomingController, :index
    get "/:group", UpcomingController, :index
  end
end
