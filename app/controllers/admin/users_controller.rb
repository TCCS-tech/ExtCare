class Admin::UsersController < Admin::BaseController
  def index
    @users = User.order(:email)
    @new_user = User.new
  end

  def create
    @new_user = User.new(user_params)

    if @new_user.save
      redirect_to admin_users_path, notice: "#{@new_user.email} added."
    else
      @users = User.order(:email)
      @user = @new_user
      render :index, status: :unprocessable_entity
    end
  end

  def update
    @user = User.find(params[:id])
    if @user.update(password_params)
      redirect_to admin_users_path, notice: "Password updated for #{@user.email}."
    else
      @users = User.order(:email)
      @new_user = User.new
      @user = User.find(params[:id])
      render :index, status: :unprocessable_entity
    end
  end

  private
    def user_params
      params.expect(user: [ :email, :password, :password_confirmation, :role ])
    end

    def password_params
      params.expect(user: [ :password, :password_confirmation ])
    end
end
