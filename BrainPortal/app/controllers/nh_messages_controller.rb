
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
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

# RESTful controller for managing Messages.
class NhMessagesController < NeurohubApplicationController
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include Pagy::Backend

  before_action :login_required

  # GET /messages
  # GET /messages.xml
  def index #:nodoc:
    @messages = Message.where(:user_id => current_user.available_users.map(&:id))
    @messages_count = @messages.count

    @page, @per_page = pagination_check(@messages, :nh_messages)
    @pagy, @messages = pagy(@messages, :items => @per_page)

    @read_count   = @messages.where(:user_id => current_user.id, :read => true).count
    @unread_count = @messages.where(:user_id => current_user.id, :read => false).count
  end

  def new #:nodoc:
    @message       = Message.new # blank object for new() form.
    @message.message_type = :correspondence
    @message.header = "A personal message from #{current_user.full_name || current_user.login}"
    @nh_projects   = find_nh_projects(current_user)
  end

  # POST /messages
  # POST /messages.xml
  def create #:nodoc:
    @message = Message.new(message_params)

    date = params[:expiry_date] || ""
    hour = params[:expiry_hour] || "00"
    min  = params[:expiry_min]  || "00"
    date = Date.today if date.blank? && (hour != "00" || min != "00")
    unless date.blank?
      string_time = "#{date} #{hour}:#{min} #{Time.now.in_time_zone.formatted_offset}"
      full_date = DateTime.parse(string_time)
      @message.expiry = full_date
    end

    if @message.header.blank?
      @message.errors.add(:header, "cannot be left blank.")
    end

    @group_id = params[:group_id]
    if @group_id.blank?
      @message.errors.add(:base, "You need to specify the project whose members will receive this message.")
    elsif @message.errors.empty?
      group = current_user.assignable_groups.find(@group_id)
      if group
        @message.send_me_to(group)
      else
        @message.errors.add(:base, "Invalid project specified for message destination.")
      end
    end
    # prepare_messages

    if @message.errors.empty?
      flash.now[:notice] = 'Message was successfully sent.'
      redirect_to :action => :index
    else
      render :action => :new
    end
  end

  # PUT /messages/1
  # PUT /messages/1.xml
  def update #:nodoc:
    @message = current_user.messages.find(params[:id])

    respond_to do |format|
      if @message.update_attributes(:read =>  params[:read])
        format.xml  { head :ok }
        format.js   { head :ok }
      else
        flash.now[:error] = "Problem updating message."
        format.xml  { render :xml  => @message.errors, :status => :unprocessable_entity }
        format.js   { render :json => @message.errors, :status => :unprocessable_entity }
      end
    end
  end

  # todo serge delete?

  # # Delete multiple messages.
  # def delete_messages
  #   id_list = params[:message_ids] || []
  #   if current_user.has_role?(:admin_user)
  #     message_list = Message.where(:id => id_list).all
  #   else
  #     message_list = current_user.messages.where(:id => id_list).all
  #   end
  #   deleted_count = 0
  #
  #   message_list.each do |message_item|
  #     deleted_count += 1
  #     message_item.destroy
  #   end
  #
  #   flash[:notice] = "#{view_pluralize(deleted_count, "item")} deleted.\n"
  #   redirect_to :action => :index
  # end

  # DELETE /messages/1
  # DELETE /messages/1.xml
  def destroy #:nodoc:
    if current_user.has_role?(:admin_user)
      @message = Message.find(params[:id]) rescue nil
    else
      @message = current_user.messages.find(params[:id]) rescue nil
    end
    @message && @message.destroy

    redirect_to :action => :index
  end

  private

  def message_params
    params.require(:message).permit(:header, :description, :variable_text, :message_type, :read, :user_id, :expiry, :last_sent, :critical, :display, :send_email, :group_id, :sender_id)
  end
end
