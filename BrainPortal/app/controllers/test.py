respond_to do |format|
  if @tool_config.save_with_logging(current_user, %w( env_array script_prologue ncpus ))
    flash[:notice] = "Tool configuration was successfully updated."
    format.html {
      if id.present?
        render :action => "show"
      elsif  @tool_config.tool_id
        redirect_to edit_tool_path(@tool_config.tool)
      else
        redirect_to bourreau_path(@tool_config.bourreau)
      end
    }
    format.xml  { head :ok }
  else
    format.html { render :action => "show" }
    format.xml  { render :xml => @tool_config.errors, :status => :unprocessable_entity }
  end
end