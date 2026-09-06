class MessagesController < ApplicationController
  def index
    @messages = Message.all
    @dexie_stream = "message_channel"
  end

  def create
    Message.create!(body: params[:body])
    head :ok
  end
end
