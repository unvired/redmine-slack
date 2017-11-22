require 'httpclient'
require "json"

class ChymeListener < Redmine::Hook::Listener
	def controller_issues_new_after_save(context={})
		issue = context[:issue]

		channel = channel_for_project issue.project
		url = url_for_project issue.project
		assistant = assistant_for_project issue.project

		return unless channel and url and assistant
		return if issue.is_private?

		msg = "[#{escape issue.project}] #{escape issue.author} created <#{object_url issue}|#{escape issue}>#{mentions issue.description}"
		followUpRecipes = [{:nlpSuggestionText => "Update issue", :nlpText => "Update issue"}]
		issueBizEntity = issue_to_business_entity issue, followUpRecipes
		speak msg, channel, assistant, issueBizEntity, url
	end

	def controller_issues_edit_after_save(context={})
		issue = context[:issue]
		journal = context[:journal]

		channel = channel_for_project issue.project
		url = url_for_project issue.project
		assistant = assistant_for_project issue.project

		return unless channel and url and assistant and Setting.plugin_redmine_chyme['post_updates'] == '1'
		return if issue.is_private?
		return if journal.private_notes?

        msg = "[#{escape issue.project}] #{escape journal.user.to_s} updated #{escape issue}: #{object_url issue}#{mentions journal.notes}"
        msg = "#{msg}\nNote: #{journal.notes}" if journal.notes

        journal.details.map.each do |d|
                msg = "#{msg}\n#{detail_to_field d}"
        end

		followUpRecipes = [{:nlpSuggestionText => "Update issue", :nlpText => "Update issue"}]
		issueBizEntity = issue_to_business_entity issue, followUpRecipes

		speak msg, channel, assistant, issueBizEntity, url
	end

	def model_changeset_scan_commit_for_issue_ids_pre_issue_update(context={})
		issue = context[:issue]
		journal = issue.current_journal
		changeset = context[:changeset]

		channel = channel_for_project issue.project
		url = url_for_project issue.project
		assistant = assistant_for_project issue.project

		return unless channel and url and assistant and issue.save
		return if issue.is_private?

		repository = changeset.repository

		if Setting.host_name.to_s =~ /\A(https?\:\/\/)?(.+?)(\:(\d+))?(\/.+)?\z/i
			host, port, prefix = $2, $4, $5
			revision_url = Rails.application.routes.url_for(
				:controller => 'repositories',
				:action => 'revision',
				:id => repository.project,
				:repository_id => repository.identifier_param,
				:rev => changeset.revision,
				:host => host,
				:protocol => Setting.protocol,
				:port => port,
				:script_name => prefix
			)
		else
			revision_url = Rails.application.routes.url_for(
				:controller => 'repositories',
				:action => 'revision',
				:id => repository.project,
				:repository_id => repository.identifier_param,
				:rev => changeset.revision,
				:host => Setting.host_name,
				:protocol => Setting.protocol
			)
		end

		msg = "[#{escape issue.project}] #{escape journal.user.to_s} updated <#{object_url issue}|#{escape issue}> <#{revision_url}|#{escape changeset.comments}>"
        msg = "#{msg}\nNote: #{journal.notes}" if journal.notes

        journal.details.map.each do |d|
                msg = "#{msg}\n#{detail_to_field d}"
        end

		followUpRecipes = [{:nlpSuggestionText => "Update issue", :nlpText => "Update issue"}]
		issueBizEntity = issue_to_business_entity issue, followUpRecipes
		speak msg, channel, assistant, issueBizEntity, url
	end

	def speak(msg, channel, assistant, data, url=nil)
		url = Setting.plugin_redmine_chyme['chyme_url'] if not url

		begin
			client = HTTPClient.new
			client.ssl_config.cert_store.set_default_paths
			client.ssl_config.ssl_version = :auto
			client.post_async url, {:message => msg, :recipient => channel, :assistant => assistant, :messageType => "ALERT", :data => data.to_json}
		rescue Exception => e
			Rails.logger.warn("cannot connect to #{url}")
			Rails.logger.warn(e)
		end
	end

private
	def escape(msg)
		msg.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
	end

	def object_url(obj)
		if Setting.host_name.to_s =~ /\A(https?\:\/\/)?(.+?)(\:(\d+))?(\/.+)?\z/i
			host, port, prefix = $2, $4, $5
			Rails.application.routes.url_for(obj.event_url({
				:host => host,
				:protocol => Setting.protocol,
				:port => port,
				:script_name => prefix
			}))
		else
			Rails.application.routes.url_for(obj.event_url({
				:host => Setting.host_name,
				:protocol => Setting.protocol
			}))
		end
	end

	def url_for_project(proj)
		return nil if proj.blank?

		cf = ProjectCustomField.find_by_name("Chyme URL")

		return [
			(proj.custom_value_for(cf).value rescue nil),
			(url_for_project proj.parent),
			Setting.plugin_redmine_chyme['chyme_url'],
		].find{|v| v.present?}
	end

	def channel_for_project(proj)
		return nil if proj.blank?

		cf = ProjectCustomField.find_by_name("Chyme Channel")

		val = [
			(proj.custom_value_for(cf).value rescue nil),
			(channel_for_project proj.parent),
			Setting.plugin_redmine_chyme['channel'],
		].find{|v| v.present?}

		# Channel name '-' is reserved for NOT notifying
		return nil if val.to_s == '-'
		val
	end

	def assistant_for_project(proj)
		return nil if proj.blank?

		cf = ProjectCustomField.find_by_name("Chyme Assistant")

		return [
			(proj.custom_value_for(cf).value rescue nil),
			(assistant_for_project proj.parent),
			Setting.plugin_redmine_chyme['assistant'],
		].find{|v| v.present?}

	end

	def issue_to_business_entity(issue, followUpRecipes)
		return {:beList => {:ISSUE => [{:ISSUE_HEADER => {:ISSUE_ID => issue.id, :PROJECT => issue.project.name, :PROJECT_ID => issue.project.id, :TRACKER => issue.tracker.name, :STATUS => issue.status.name, :PRIORITY => issue.priority.name, :SUBJECT => issue.subject, :DESCRIPTION => issue.description, :START_DATE => issue.start_date, :DONE_RATIO => issue.done_ratio.to_s, :CREATED_ON => issue.created_on, :UPDATED_ON => issue.updated_on}}]}, :sendBE => "true", :followUpRecipes => followUpRecipes.to_json}
	end

	def detail_to_field(detail)
		if detail.property == "cf"
			key = CustomField.find(detail.prop_key).name rescue nil
			title = key
		elsif detail.property == "attachment"
			key = "attachment"
			title = I18n.t :label_attachment
		else
			key = detail.prop_key.to_s.sub("_id", "")
			if key == "parent"
				title = I18n.t "field_#{key}_issue"
			else
				title = I18n.t "field_#{key}"
			end
		end

		value = escape detail.value.to_s

		case key
		when "tracker"
			tracker = Tracker.find(detail.value) rescue nil
			value = escape tracker.to_s
		when "project"
			project = Project.find(detail.value) rescue nil
			value = escape project.to_s
		when "status"
			status = IssueStatus.find(detail.value) rescue nil
			value = escape status.to_s
		when "priority"
			priority = IssuePriority.find(detail.value) rescue nil
			value = escape priority.to_s
		when "category"
			category = IssueCategory.find(detail.value) rescue nil
			value = escape category.to_s
		when "assigned_to"
			user = User.find(detail.value) rescue nil
			value = escape user.to_s
		when "fixed_version"
			version = Version.find(detail.value) rescue nil
			value = escape version.to_s
		when "attachment"
			attachment = Attachment.find(detail.prop_key) rescue nil
			value = "<#{object_url attachment}|#{escape attachment.filename}>" if attachment
		when "parent"
			issue = Issue.find(detail.value) rescue nil
			value = "<#{object_url issue}|#{escape issue}>" if issue
		end

		value = "-" if value.empty?

		result = "#{title} : #{value}"
		result
	end

	def mentions text
		names = extract_usernames text
		names.present? ? "\nTo: " + names.join(', ') : nil
	end

	def extract_usernames text = ''
		if text.nil?
			text = ''
		end

		# chyme usernames may only contain lowercase letters, numbers,
		# dashes and underscores and must start with a letter or number.
		text.scan(/@[a-z0-9][a-z0-9_\-]*/).uniq
	end
end
