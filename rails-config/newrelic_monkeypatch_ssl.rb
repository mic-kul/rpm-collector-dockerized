# Turn off SSL for NR gem
require 'new_relic/agent/new_relic_service'
module NewRelic
  module Agent
    class NewRelicService
      def setup_connection_for_ssl(conn)
        # Jruby 1.6.8 requires a gem for full ssl support and will throw
        # an error when use_ssl=(true) is called and jruby-openssl isn't
        # installed
        conn.use_ssl     = false
        conn.verify_mode = OpenSSL::SSL::VERIFY_PEER
        conn.cert_store  = ssl_cert_store
      rescue StandardError, LoadError
        msg = "SSL is not available in the environment; please install SSL support."
        raise UnrecoverableAgentException.new(msg)
      end
    end
  end
end