require 'httpclient'
require "json"

require_relative "chymehelper"

class ChymeViewListener < Redmine::Hook::ViewListener
	def controller_issues_new_before_save(context={})
		issue = context[:issue]

		channel = ChymeHelper.channel_for_project issue.project
		url = ChymeHelper.url_for_project issue.project
		assistant = ChymeHelper.assistant_for_project issue.project

		return unless channel and url and assistant
		return if issue.is_private?

		msg = "[#{ChymeHelper.escape issue.project}] #{ChymeHelper.escape issue.author} created issue: #{ChymeHelper.mentions issue.description}"
		convId = ChymeHelper.speak nil, msg, channel, assistant, nil, nil, url
		context[:issue].chyme_conversation_id = convId
	end
end
