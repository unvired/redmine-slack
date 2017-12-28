require 'httpclient'
require "json"

class ChymeHelper

	class << self

		def speak(convId, msg, channel, assistant, data, followUps, url=nil)
			url = Setting.plugin_redmine_chyme['chyme_url'] if not url
			url = url + "/messages"
			convId = "" if not convId;
			data = "" if not data;
			followUps = "" if not followUps;

			begin
				client = HTTPClient.new
				client.ssl_config.cert_store.set_default_paths
				client.ssl_config.ssl_version = :auto
				connection = client.post_async url, {:message => msg, :recipient => channel, :conversationId => convId, :assistant => assistant, :messageType => "ALERT", :data => data.to_json, :followUpRecipes => followUps.to_json}
				while true
	                break if connection.finished?
	                	sleep 1
	            end
	            response = connection.pop
	            conversation = JSON.parse(response.content.read)
	            return conversation['conversationId']

			rescue Exception => e
				Rails.logger.warn("cannot connect to #{url}")
				Rails.logger.warn(e)
			end
		end

		def escape(msg)
			msg.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
		end

		def object_url(obj)
			Rails.logger.warn("OBJECT URL 1 #{obj.event_url}")
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

		def issue_to_business_entity(issue)
			return {:beList => {:ISSUE => [{:ISSUE_HEADER => {:ISSUE_ID => issue.id, :PROJECT => issue.project.name, :PROJECT_ID => issue.project.id, :TRACKER => issue.tracker.name, :STATUS => issue.status.name, :PRIORITY => issue.priority.name, :SUBJECT => issue.subject, :DESCRIPTION => issue.description, :START_DATE => issue.start_date, :DONE_RATIO => issue.done_ratio.to_s, :CREATED_ON => issue.created_on, :UPDATED_ON => issue.updated_on}}]}, :sendBE => "false"}
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

			value = ChymeHelper.escape detail.value.to_s

			case key
			when "tracker"
				tracker = Tracker.find(detail.value) rescue nil
				value = ChymeHelper.escape tracker.to_s
			when "project"
				project = Project.find(detail.value) rescue nil
				value = ChymeHelper.escape project.to_s
			when "status"
				status = IssueStatus.find(detail.value) rescue nil
				value = ChymeHelper.escape status.to_s
			when "priority"
				priority = IssuePriority.find(detail.value) rescue nil
				value = ChymeHelper.escape priority.to_s
			when "category"
				category = IssueCategory.find(detail.value) rescue nil
				value = ChymeHelper.escape category.to_s
			when "assigned_to"
				user = User.find(detail.value) rescue nil
				value = ChymeHelper.escape user.to_s
			when "fixed_version"
				version = Version.find(detail.value) rescue nil
				value = ChymeHelper.escape version.to_s
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
end
