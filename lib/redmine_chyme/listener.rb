require 'httpclient'
require "json"

require_relative "chymehelper"

class ChymeListener < Redmine::Hook::Listener
	def controller_issues_new_after_save(context={})
		issue = context[:issue]

		channel = ChymeHelper.channel_for_project issue.project
		url = ChymeHelper.url_for_project issue.project
		assistant = ChymeHelper.assistant_for_project issue.project

		return unless channel and url and assistant
		return if issue.is_private?

		msg = "[#{ChymeHelper.escape issue.project}] #{ChymeHelper.escape issue.author} created <#{ChymeHelper.object_url issue}|#{ChymeHelper.escape issue}>#{ChymeHelper.mentions issue.description}"
		followUpRecipes = [{:nlpSuggestionText => "Update issue", :nlpText => "Update issue"}]
		issueBizEntity = ChymeHelper.issue_to_business_entity issue
		ChymeHelper.speak issue.chyme_conversation_id, msg, channel, assistant, issueBizEntity, followUpRecipes, url
	end

	def controller_issues_edit_after_save(context={})
		issue = context[:issue]
		journal = context[:journal]

		channel = ChymeHelper.channel_for_project issue.project
		url = ChymeHelper.url_for_project issue.project
		assistant = ChymeHelper.assistant_for_project issue.project

		return unless channel and url and assistant and Setting.plugin_redmine_chyme['post_updates'] == '1'
		return if issue.is_private?
		return if journal.private_notes?

        msg = "[#{ChymeHelper.escape issue.project}] #{ChymeHelper.escape journal.user.to_s} updated #{ChymeHelper.escape issue}: #{ChymeHelper.object_url issue}#{ChymeHelper.mentions journal.notes}"
        msg = "#{msg}\nNote: #{journal.notes}" if journal.notes

        journal.details.map.each do |d|
                msg = "#{msg}\n#{detail_to_field d}"
        end

		followUpRecipes = [{:nlpSuggestionText => "Update issue", :nlpText => "Update issue"}]
		issueBizEntity = ChymeHelper.issue_to_business_entity issue

		ChymeHelper.speak issue.chyme_conversation_id, msg, channel, assistant, issueBizEntity, followUpRecipes, url
	end

	def model_changeset_scan_commit_for_issue_ids_pre_issue_update(context={})
		issue = context[:issue]
		journal = issue.current_journal
		changeset = context[:changeset]

		channel = ChymeHelper.channel_for_project issue.project
		url = ChymeHelper.url_for_project issue.project
		assistant = ChymeHelper.assistant_for_project issue.project

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

		msg = "[#{ChymeHelper.escape issue.project}] #{ChymeHelper.escape journal.user.to_s} updated <#{ChymeHelper.object_url issue}|#{ChymeHelper.escape issue}> <#{revision_url}|#{ChymeHelper.escape changeset.comments}>"
        msg = "#{msg}\nNote: #{journal.notes}" if journal.notes

        journal.details.map.each do |d|
                msg = "#{msg}\n#{detail_to_field d}"
        end

		followUpRecipes = [{:nlpSuggestionText => "Update issue", :nlpText => "Update issue"}]
		issueBizEntity = ChymeHelper.issue_to_business_entity issue
		ChymeHelper.speak issue.chyme_conversation_id, msg, channel, assistant, issueBizEntity, followUpRecipes, url
	end
end
