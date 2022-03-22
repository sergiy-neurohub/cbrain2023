
#
# NeuroHub Project
#
# Copyright (C) 2020
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

#Controller for the User resource.
class NhUsersController < NeurohubApplicationController

  include EnvokeHelpers

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include OrcidHelpers
  include GlobusHelpers

  before_action :login_required

  def show #:nodoc:
    @user = User.find(params[:id])
    unless current_user.available_users.to_a.include?(@user)
      cb_error "You don't have permission to view this user.", :redirect => :neurohub
      # probably not needed until admin/manager etc added...
    end
  end

  def myaccount #:nodoc:
    @user=current_user
    @orcid_canonical = orcid_canonize(@user.meta[:orcid])
    render :show
  end

  def edit #:nodoc:
    @envoke_auth_configured = envoke_auth_configured?
    @user = User.find(params[:id])
    unless @user.id == current_user.id
      cb_error "You don't have permission to view this user.", :redirect => :neurohub
      # to change if admin/manager etc added...
      # todo move to security helpers
    end

    @orcid_canonical = orcid_canonize(@user.meta[:orcid])
    @orcid_uri       = orcid_login_uri() # set to nil if orcid not configured by admin
    @globus_uri      = globus_login_uri(nh_globus_url) # set to nil if globus not configured by admin
  end

  def change_password #:nodoc:
    @user = current_user
  end

  def update
    @user = User.find(params[:id])

    unless @user.id == current_user.id
      cb_error "You don't have permission to edit this user or user does not exists.", :redirect  => :neurohub
    end

    attr_to_update = params.require_as_params(:user).permit( [
      :full_name, :email, :time_zone, :password, :password_confirmation,
      :city, :country, :affiliation, :position, :zenodo_sandbox_token, :zenodo_main_token,
      :maillist_consent
    ])

    # Do not zap tokens if the user left them blank
    attr_to_update.delete(:zenodo_sandbox_token) if attr_to_update[:zenodo_sandbox_token].blank?
    attr_to_update.delete(:zenodo_main_token)    if attr_to_update[:zenodo_main_token].blank?

    if envoke_auth_configured?
      # not sure should we board users from myaccount page, as my user possibly changed email
      # to possibly uncofirmed email or even another user email
      # if ! envoke_contact_with_email(@user.email) && ! $user.envoke_id
      #  envoke_add_user(@user)      #
      # end
      if @user.maillist_consent != params[:user][:maillist_consent]
      # begin
        r = envoke_reopt_in(@user) if params[:user][:maillist_consent] == 'Yes'
        r = envoke_reopt_out(@user) if params[:user][:maillist_consent] == 'No'
        flash[:notice] = "Your change to Newsletter subscription failed." unless r
      # rescue StandardError => e
      #   flash[:warning] = "Your change to mail list subscription did not take effect, please contact your admin."
      #   cb_error(e.message)
      # end
      elsif @user_id
      end

    end

    last_update = @user.updated_at
    if @user.update_attributes_with_logging(attr_to_update, current_user)
      if attr_to_update[:password].present?
        flash[:notice] = "Your password was changed."
        @user.update_column(:password_reset, false)
        redirect_to nh_projects_path
      else
        flash[:notice] = "User #{@user.login} was successfully updated." if @user.updated_at != last_update
        redirect_to :action => :myaccount
      end
    else
      if attr_to_update[:password].present?
        render :action => :change_password
      else
        render :action => :edit
      end
    end
  end

  # POST /users/new_token
  def new_token
    new_session = cbrain_session.duplicate_with_new_token
    @new_token  = new_session.cbrain_api_token
  end

  # POST /unlink_orcid
  def unlink_orcid #:nodoc:
    redirect_to :neurohub unless current_user

    current_user.meta[:orcid] = nil
    flash[:notice] = "This ORCID iD was removed from your NeuroHub account"
    redirect_to :action => :myaccount
  end

end
