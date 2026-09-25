class Admin::TasksController < Admin::BaseController
  def index
    @task ||= Task.new
    @todo_tasks = Task.todo.ordered.includes(:created_by)
    @done_tasks = Task.done.ordered.includes(:created_by)
  end

  def create
    @task = Task.new(task_params.merge(created_by: Current.user))

    if @task.save
      redirect_to admin_tasks_path, notice: "Task added."
    else
      index
      render :index, status: :unprocessable_entity
    end
  end

  def update
    task = Task.find(params[:id])
    if task.update(task_params)
      redirect_to admin_tasks_path, notice: "Task updated."
    else
      redirect_to admin_tasks_path, alert: task.errors.full_messages.to_sentence
    end
  end

  def destroy
    Task.find(params[:id]).destroy!
    redirect_to admin_tasks_path, notice: "Task deleted."
  end

  def reorder
    status = params[:status]
    task_ids = params[:task_ids]
    return head :unprocessable_entity unless Task.statuses.key?(status) && task_ids.is_a?(Array)

    tasks = Task.where(id: task_ids).index_by { |task| task.id.to_s }
    return head :unprocessable_entity unless tasks.size == task_ids.uniq.size && tasks.size == task_ids.size

    Task.transaction do
      tasks.each_value { |task| task.update!(status: status) if task.status != status }
      task_ids.each_with_index do |id, index|
        task = tasks.fetch(id)
        task.update!(priority: index) unless task.priority == index
      end
    end

    head :no_content
  end

  private
    def task_params
      params.expect(task: [ :title, :description ])
    end
end
