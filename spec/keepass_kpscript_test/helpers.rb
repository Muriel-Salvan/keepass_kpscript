require 'stringio'
require 'keepass_kpscript'

module KeepassKpscriptTest

  module Helpers

    # Expect some calls to be done on KPScript
    #
    # Parameters::
    # * *expected_calls* (Array<[String, String or Hash]>): The list of calls and their corresponding mocked response:
    #   * String: Mocked stdout
    #   * Hash<Symbol,Object>: More complete structure defining the mocked response:
    #     * *exit_status* (Integer): The command exit status [default: 0]
    #     * *stdout* (String): The command stdout
    def expect_calls_to_kpscript(expected_calls)
      if expected_calls.empty?
        expect(Open3).not_to receive(:popen3)
      else
        expected_calls.each do |(expected_call, mocked_call)|
          mocked_call = { stdout: mocked_call } if mocked_call.is_a?(String)
          mocked_call[:exit_status] = 0 unless mocked_call.key?(:exit_status)
          expect(Open3).to receive(:popen3).with(expected_call) do |_cmd, &block|
            wait_thr_double = instance_double(Process::Waiter)
            allow(wait_thr_double).to receive(:value) do
              wait_thr_value_double = instance_double(Process::Status)
              allow(wait_thr_value_double).to receive(:exitstatus) do
                mocked_call[:exit_status]
              end
              wait_thr_value_double
            end
            block.call(
              StringIO.new,
              StringIO.new(mocked_call[:stdout]),
              StringIO.new,
              wait_thr_double
            )
          end
        end
      end
    end

  end

end

RSpec.configure do |config|
  config.include KeepassKpscriptTest::Helpers

  config.before do
    # Make sure log debugs are not output on screen during tests
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(KeepassKpscript::Kpscript).to receive(:log_debug).and_yield
    # rubocop:enable RSpec/AnyInstance
  end
end
