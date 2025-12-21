class ErrorsChannel < ApplicationCable::Channel
  def subscribed
    project = Project.find_by(id: params[:project_id])
    if project
      stream_for project
    else
      reject
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
