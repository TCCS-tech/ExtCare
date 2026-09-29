class Admin::ImportsController < Admin::BaseController
  def new
  end

  def create
    result = Student::Import.new(params[:file]).save!
    redirect_to new_admin_import_path,
      notice: "Student import complete. Added: #{result.created}, updated: #{result.updated}, unchanged: #{result.unchanged}."
  rescue Student::Import::InvalidFile => error
    flash.now[:alert] = "No students were imported. #{error.message}"
    render :new, status: :unprocessable_entity
  rescue ActiveRecord::LockWaitTimeout
    flash.now[:alert] = "No students were imported. Student records are busy. Please try again in a moment."
    render :new, status: :unprocessable_entity
  end
end
