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

  def invite
    @invite_form = true
    invitation = invitation_params
    @new_user = User.find_by(email: invitation[:email])
    existing_user = @new_user.present?

    unless existing_user
      password = SecureRandom.base58(32)
      @new_user = User.new(invitation.merge(password: password, password_confirmation: password))
    end

    if existing_user || @new_user.save
      @invite_link = "#{request.base_url}#{edit_password_path(@new_user.password_reset_token)}"
      @invite_text = if existing_user
        "Hello,\n\nYou have been invited to reset your TCCS Aftercare password. Use this link to set a new password:\n\n#{@invite_link}\n\nThis link expires in 7 days."
      else
        "Hello,\n\nYou have been invited to join TCCS Aftercare as a #{@new_user.role.downcase}. Set your password using this link:\n\n#{@invite_link}\n\nThis link expires in 7 days."
      end
      @invite_message = existing_user ? "Password reset invitation created for #{@new_user.email}." : "Invitation created for #{@new_user.email}."
      @users = User.order(:email)
      render :index, status: :created
    else
      @users = User.order(:email)
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

    def invitation_params
      params.expect(user: [ :email, :role ])
    end
end
