module Agents
  class GithubAutosyncForkAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_12h'

    description do
      <<-MD
      The Github Autosync Fork agent checks if a refresh is needed from the source.

      `repository` for the wanted repository to check.

      `token` is needed for queries.

      `debug` is used for verbose mode.

      `src_branch` is the branch's name for the source.

      `tgt_branch` is the branch's name for the target.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "message": "Successfully fetched and fast-forwarded from upstream q9f:main.",
            "merge_type": "fast-forward",
            "base_branch": "q9f:main"
          }
    MD

    def default_options
      {
        'repository' => '',
        'src_branch' => 'master',
        'tgt_branch' => 'master',
        'debug' => 'false',
        'expected_receive_period_in_days' => '2',
        'token' => ''
      }
    end

    form_configurable :repository, type: :string
    form_configurable :src_branch, type: :string
    form_configurable :tgt_branch, type: :string
    form_configurable :debug, type: :boolean
    form_configurable :token, type: :string
    form_configurable :expected_receive_period_in_days, type: :string

    def validate_options
      unless options['repository'].present?
        errors.add(:base, "repository is a required field")
      end

      unless options['src_branch'].present?
        errors.add(:base, "src_branch is a required field")
      end

      unless options['tgt_branch'].present?
        errors.add(:base, "tgt_branch is a required field")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['token'].present?
        errors.add(:base, "token is a required field")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      check_sync
    end

    private

    def log_curl_output(code,body)

      log "request status : #{code}"

      if interpolated['debug'] == 'true'
        log "body"
        log body
      end

    end

    def get_repos_info
      uri = URI.parse("https://api.github.com/repos/#{interpolated['repository']}")
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.github+json"
      request["Authorization"] = "token #{interpolated['token']}"
      request["X-Github-Api-Version"] = "2022-11-28"

      req_options = {
        use_ssl: uri.scheme == "https",
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      log_curl_output(response.code,response.body)

      payload = JSON.parse(response.body)

      compare(payload)

    end

    def compare(repo_info)

      uri = URI.parse("#{repo_info['parent']['url']}/compare/#{interpolated['src_branch']}...#{repo_info['owner']['login']}:#{interpolated['tgt_branch']}")
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.github+json"
      request["Authorization"] = "token #{interpolated['token']}"
      request["X-Github-Api-Version"] = "2022-11-28"

      req_options = {
        use_ssl: uri.scheme == "https",
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      log_curl_output(response.code,response.body)

      payload = JSON.parse(response.body)

      trigger_sync(payload)

    end

    def trigger_sync(compare_result)

      if compare_result['behind_by'] != 0

        log "we are at #{compare_result['behind_by']} commit(s) behind"
        uri = URI.parse("https://api.github.com/repos/#{interpolated['repository']}/merge-upstream")
        request = Net::HTTP::Post.new(uri)
        request["Accept"] = "application/vnd.github+json"
        request["Authorization"] = "token #{interpolated['token']}"
        request["X-Github-Api-Version"] = "2022-11-28"
        request.body = JSON.dump({
          "branch" => interpolated['tgt_branch']
        })
        
        req_options = {
          use_ssl: uri.scheme == "https",
        }
        
        response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
          http.request(request)
        end

        log_curl_output(response.code,response.body)

        payload = JSON.parse(response.body)

        create_event payload: payload
      else
        log "already up to date, nothing to sync"
      end

    end

    def check_sync

      get_repos_info

    end
  end
end
