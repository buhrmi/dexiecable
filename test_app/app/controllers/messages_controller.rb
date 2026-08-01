class MessagesController < ApplicationController
  def index
    @messages = Message.all
  end

  def create
    Message.create!(body: params[:body])
    head :ok
  end
end
